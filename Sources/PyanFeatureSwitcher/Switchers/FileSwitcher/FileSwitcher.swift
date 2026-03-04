//
//  FileSwitcher.swift
//  PyanFeatureSwitcher
//
//  Created by Perceval Archimbaud on 04/03/2026.
//

import Foundation
import Logging

/// A switcher that reads feature states from a configuration file.
///
/// `FileSwitcher` loads data through a ``FileSwitcherLoader``, parses
/// it with a ``FileSwitcherParser``, and resolves each feature to
/// either a constant state or a randomized distribution.
///
/// Use the convenience factory ``propertyList(path:options:)`` for
/// local property list files:
///
/// ```swift
/// let switcher = FileSwitcher.propertyList(
///     path: Bundle.main.url(forResource: "Features", withExtension: "plist")!
/// )
/// ```
///
/// Results can optionally be cached via ``Options`` to survive load
/// failures on subsequent launches.
public struct FileSwitcher: FeatureSwitcher {
	private let loader: FileSwitcherLoader
	private let parser: FileSwitcherParser

	private let options: Options

	/// Creates a file switcher with full control over loading and parsing.
	/// - Parameters:
	///   - loader: The loader used to get data.
	///   - parser: The parser used to interpret the file contents.
	///   - options: Configuration options. Defaults to ``Options/default`` on Apple platforms.
	#if canImport(Darwin)
	public init(
		loader: FileSwitcherLoader,
		parser: FileSwitcherParser,
		options: Options = .default
	) {
		self.loader = loader
		self.parser = parser
		self.options = options
	}
	#else
	public init(
		loader: FileSwitcherLoader,
		parser: FileSwitcherParser,
		options: Options
	) {
		self.loader = loader
		self.parser = parser
		self.options = options
	}
	#endif

	public func generateState(for features: [any Feature.Type]) async throws -> [String : any FeatureState] {
		let data: Data
		do {
			data = try await loader.loadData(filters: options.filters)
		} catch {
			guard options.allowLoadFailureRecovery else { throw error }

			let states = recoverFromCache(features)
			if !features.isEmpty && states.isEmpty {
				// We did not recover any state
				throw error
			}
			return states
		}

		let stateDescriptions = try parser.extractStateDescription(
			from: data,
			for: features,
			filters: options.filters,
			categories: options.categories
		)

		let constantSwitcher = ConstantSwitcher()
		let randomSwitcher = RandomSwitcher(cache: options.cache)

		for (identifier, description) in stateDescriptions {
			guard let feature = features.first(where: { $0.identifier == identifier }) else {
				// If this occurs, this mean used parser did not make is work properly
				assertionFailure("Unexpected feature identifier: \(identifier)")
				continue
			}

			switch description {
			case .constant(let identifier):
				guard let state = extractState(for: feature, identifier: identifier) else { break }
				constantSwitcher.constant(feature.identifier, state: state)
				options.cache.persist(state, key: feature, with: options.filters)
			case .randomized(let config):
				randomSwitcher.probabilities(for: feature.identifier, config)
			}
		}

		return try await MultiplexSwitcher(switchers: [
			randomSwitcher, // Random always defines value for all features
			constantSwitcher // Constant only defines value the user set
		]).generateState(for: features)
	}

	private func extractState(for feature: any Feature.Type, identifier: String) -> (any FeatureState)? {
		guard let state = feature.stateType.allCases.first(where: {
			($0 as? any FeatureState)?.identifier == identifier
		}) as? any FeatureState else {
			// If this occurs, this mean used parser did not make is work properly
			assertionFailure("""
			Unexpected state for feature \(feature.identifier): received \(identifier) but expected one of \
			\(feature.stateType.allCases.compactMap({ ($0 as? any FeatureState)?.identifier }))
			""")
			return nil
		}
		return state
	}

	private func recoverFromCache(_ features: [any Feature.Type]) -> [String : any FeatureState] {
		var states: [String : any FeatureState] = [:]
		for feature in features {
			states[feature.identifier] = options.cache.load(for: feature, with: options.filters)
		}
		return states
	}
}

public extension FileSwitcher {
	/// Creates a file switcher preconfigured for property list files.
	/// - Parameters:
	///   - path: The path of the `.plist` file.
	///   - options: Configuration options.
	/// - Returns: A configured ``FileSwitcher``.
	#if canImport(Darwin)
	static func propertyList(
		path: URL,
		options: Options = .default
	) -> FileSwitcher {
		return FileSwitcher(
			loader: LocalFileSwitcherLoader(path: path),
			parser: PropertyListFileSwitcherParser(),
			options: options
		)
	}
	#else
	static func propertyList(
		path: URL,
		options: Options
	) -> FileSwitcher {
		return FileSwitcher(
			loader: LocalFileSwitcherLoader(path: path),
			parser: PropertyListFileSwitcherParser(),
			options: options
		)
	}
	#endif
}

public extension FileSwitcher {
	/// Configuration for a ``FileSwitcher``.
	struct Options: Sendable {
		/// Optional filter categories for the configuration file.
		let categories: [Category]?
		/// The active filter keys (e.g. `"Debug"`, `"Release"`).
		let filters: Set<String>
		/// The cache used to persist resolved states.
		let cache: SwitcherCache
		/// When `true`, a load failure falls back to cached states instead of throwing.
		let allowLoadFailureRecovery: Bool

		/// Creates options with the given configuration.
		/// - Parameters:
		///   - filters: Active filter keys to select the matching branch in the file.
		///   - categories: Optional category definitions that validate filter exclusivity.
		///   - cache: The cache for persisting resolved states.
		///   - allowLoadFailureRecovery: Whether to recover from load failures using cached states.
		/// - Throws: ``OptionError`` if the filters or categories are invalid.
		public init(
			filters: Set<String>,
			categories: [Category]? = nil,
			cache: SwitcherCache,
			allowLoadFailureRecovery: Bool = true
		) throws {
			// Ensure options are valid
			if let categories {
				let allChoices: [String] = categories.reduce([], { $0 + $1.choices })
				guard allChoices.count == Set(allChoices).count else {
					throw OptionError.conflictingCategories
				}
				var availableCategories = categories
				for filter in filters {
					guard let index = availableCategories.firstIndex(where: { $0.choices.contains(filter) }) else {
						if categories.contains(where: { $0.choices.contains(filter) }) {
							throw OptionError.conflictingFilter(filter)
						} else {
							throw OptionError.unexpectedFilter(filter)
						}
					}
					availableCategories.remove(at: index)
				}
			}

			self.categories = categories
			self.filters = filters
			self.cache = cache
			self.allowLoadFailureRecovery = allowLoadFailureRecovery
		}

		init(cache: SwitcherCache) {
			self.categories = nil
			self.filters = []
			self.cache = cache
			self.allowLoadFailureRecovery = true
		}

		/// A group of mutually exclusive filter choices.
		///
		/// Use categories to declare that certain filter keys cannot
		/// appear together (e.g. `"Debug"` and `"Release"` are exclusive).
		public struct Category: Sendable {
			let choices: Set<String>

			/// Creates a category from a set of mutually exclusive choices.
			public static func exclusive(_ choices: Set<String>) -> Self {
				return .init(choices: choices)
			}
		}

		/// Errors thrown when ``Options`` validation fails.
		public enum OptionError: Error {
			/// A filter does not belong to any declared category.
			case unexpectedFilter(String)
			/// Two filters from the same exclusive category were provided.
			case conflictingFilter(String)
			/// Two categories share a common choice.
			case conflictingCategories
		}
	}
}

extension FileSwitcher.Options {
	public var logMetadata: Logger.Metadata {
		return [
			"categories": .array(categories?.map({ category in
				return .array(category.choices.map(Logger.MetadataValue.string))
			}) ?? []),
			"filters": .array(filters.map(Logger.MetadataValue.string)),
			"cache": .string(String(describing: type(of: cache))),
			"allowLoadFailureRecovery": .string(String(describing: allowLoadFailureRecovery))
		]
	}
}


#if os(macOS) || os(iOS) || os(watchOS) || os(tvOS) || os(visionOS)
public extension FileSwitcher.Options {
	static var `default`: Self {
		return .init(cache: UserDefaultsSwitcherCache())
	}
}
#endif

extension FileSwitcher {
	public var logMetadata: Logger.Metadata {
		return [
			"loader": .string(String(describing: type(of: loader))),
			"parser": .string(String(describing: type(of: parser))),
			"options": .dictionary(options.logMetadata)
		]
	}
}
