//
//  MultiplexSwitcher.swift
//  PyanFeatureSwitcher
//
//  Created by Perceval Archimbaud on 04/03/2026.
//

import Foundation
import Logging

/// A switcher that composes multiple ``FeatureSwitcher`` instances
/// and merges their results.
///
/// When several switchers resolve the same feature, the **last**
/// switcher in the array wins. This lets you layer strategies —
/// for example a ``RandomSwitcher`` base with a ``ConstantSwitcher``
/// override on top.
///
/// ```swift
/// let switcher = MultiplexSwitcher(switchers: [
///     RandomSwitcher(),
///     ConstantSwitcher().constant(DarkMode.self, enabled: true)
/// ])
/// ```
///
/// You can also create a multiplex switcher through the convenience
/// ``FeatureSwitcher/multiplex(_:)`` extension.
public struct MultiplexSwitcher: FeatureSwitcher {
	/// The ordered list of switchers whose results are merged.
	let switchers: [FeatureSwitcher]

	/// Creates a multiplex switcher from the given list.
	/// - Parameter switchers: The switchers to compose.
	///   Later entries take precedence over earlier ones.
	public init(switchers: [FeatureSwitcher]) {
		self.switchers = switchers
	}

	public func generateState(for features: [any Feature.Type]) async throws -> [String: any FeatureState] {
		var states: [String: any FeatureState] = [:]

		for switcher in switchers {
			// Later takes precedence
			states.merge(try await switcher.generateState(for: features), uniquingKeysWith: { $1 })
		}

		return states
	}
}

extension MultiplexSwitcher {
	public var logMetadata: Logger.Metadata {
		return [
			"switchers": .array(switchers.map({ switcher in
				.dictionary(switcher.logMetadata.merging([
					"type": .string(String(describing: type(of: switcher)))
				], uniquingKeysWith: { switcherMetadata, _ in switcherMetadata }))
			}))
		]
	}
}
