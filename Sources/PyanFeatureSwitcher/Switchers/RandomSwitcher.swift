//
//  RandomSwitcher.swift
//  PyanFeatureSwitcher
//
//  Created by Perceval Archimbaud on 04/03/2026.
//

import Foundation
import Synchronization
import Logging

/// A switcher that assigns feature states randomly based on
/// configurable probabilities.
///
/// Once a state is randomly selected for a feature, it is persisted
/// in the provided ``SwitcherCache`` so subsequent launches return
/// the same value.
///
/// ```swift
/// let switcher = RandomSwitcher()
///     .probabilities(for: OnboardingFlow.self, [
///         .classic: 0.5,
///         .redesigned: 0.3,
///         .experimental: 0.2
///     ])
/// ```
///
/// States without explicit probabilities share the remaining
/// probability equally.
public final class RandomSwitcher: FeatureSwitcher {
	private let cache: SwitcherCache
	private let randomGenerator: @Sendable (ClosedRange<Double>) -> Double

	private let probabilitiesConfiguration = Mutex<[String: [String: Double]]>([:])

	/// Creates a random switcher.
	/// - Parameter cache: The cache used to persist assigned states.
	///   Defaults to ``UserDefaultsSwitcherCache`` on Apple platforms.
	#if canImport(Darwin)
	public init(cache: SwitcherCache = UserDefaultsSwitcherCache()) {
		self.cache = cache
		self.randomGenerator = Double.random
	}
	#else
	public init(cache: SwitcherCache) {
		self.cache = cache
		self.randomGenerator = Double.random
	}
	#endif

	internal init(
		cache: SwitcherCache = InMemorySwitcherCache(),
		randomGenerator: @escaping @Sendable (ClosedRange<Double>) -> Double
	) {
		self.cache = cache
		self.randomGenerator = randomGenerator
	}

	/// Configures the probability distribution for a feature's states.
	///
	/// The sum of all probabilities must not exceed `1.0`. Any remaining
	/// probability is distributed equally among unconfigured states.
	///
	/// > notice: If the cumulated probabilities exceed `1.0`, this is **undefined behavior**. You
	/// can usually expect the probabilities to be added sequentially and ignored once you
	/// reached or exceeded `1.0`.
	///
	/// - Parameters:
	///   - featureType: The ``Feature`` type.
	///   - probabilities: A mapping from state to its probability (0...1).
	/// - Returns: `self`, for chaining.
	@discardableResult
	public func probabilities<F: Feature>(for featureType: F.Type, _ probabilities: [F.State: Double]) -> Self {
		var proba: [String: Double] = [:]
		for (key, value) in probabilities {
			proba[key.identifier] = value
		}
		return self.probabilities(for: featureType.identifier, proba)
	}

	public func generateState(for features: [any Feature.Type]) async throws -> [String: any FeatureState] {
		var states: [String: any FeatureState] = [:]

		for featureType in features {
			// Always use memory if available
			if let inMemory = cache.load(for: featureType) {
				states[featureType.identifier] = inMemory
				continue
			}

			let random = randomGenerator(0...1)

			let definedProba = probabilitiesConfiguration.withLock { $0[featureType.identifier] } ?? [:]
			let totalStateCount = featureType.stateType.allCases.count
			let totalDefinedProba = definedProba.values.reduce(0.0, { min(1, $0 + $1) })
			let undefinedCount = totalStateCount - definedProba.count
			let defaultProbability = undefinedCount == 0 ? 0 : (1.0 - totalDefinedProba) / Double(undefinedCount)

			var threshold = 0.0
			for state in featureType.stateType.allCases {
				guard let state = state as? any FeatureState else { continue }
				threshold += definedProba[state.identifier] ?? defaultProbability
				if random < threshold {
					states[featureType.identifier] = state
					// We do not want to pick different state at execution
					cache.persist(state, key: featureType)
					break
				}
			}
		}

		return states
	}
}

extension RandomSwitcher {
	@discardableResult
	func probabilities(for identifier: String, _ probabilities: [String: Double]) -> Self {
		probabilitiesConfiguration.withLock { $0[identifier] = [:] }
		var total = 0.0
		for (key, value) in probabilities {
			total += value
			guard total <= 1.0 else {
				// Never set more than 1.0 for cumulated probabilities
				assertionFailure("The union of defined cases probabilities exceed 1")
				return self
			}
			probabilitiesConfiguration.withLock { $0[identifier]![key] = value }
		}
		return self
	}
}

extension RandomSwitcher {
	public var logMetadata: Logger.Metadata {
		return [
			"cache": .string(String(describing: type(of: cache)))
		]
	}
}
