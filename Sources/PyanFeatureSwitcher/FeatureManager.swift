//
//  FeatureManager.swift
//  PyanFeatureSwitcher
//
//  Created by Perceval Archimbaud on 04/03/2026.
//

import Foundation
import Synchronization
import Logging

/// The central entry point for resolving feature states.
///
/// `FeatureManager` holds a set of registered features, delegates
/// state resolution to a ``FeatureSwitcher``, and caches the results
/// for the lifetime of the manager.
///
/// ```swift
/// let manager = FeatureManager(switcher: mySwitcher)
///     .register(DarkMode.self)
///     .register(OnboardingFlow.self)
///
/// try await manager.bootstrap()
///
/// if manager.isEnabled(DarkMode.self) {
///     // apply dark theme
/// }
/// ```
///
/// > Important: Call ``bootstrap()`` exactly once before querying state.
@Observable
public final class FeatureManager {
	private var states: [String: any FeatureState]? = nil
	private var features: [any Feature.Type] = []

	/// The switcher responsible for resolving each registered feature's state during ``bootstrap()``.
	let switcher: FeatureSwitcher

	/// Indicates if this manager ready to use.
	public var isReady: Bool { states != nil }

	/// Creates a manager that will use the given switcher to resolve feature states.
	/// - Parameter switcher: The ``FeatureSwitcher`` responsible for generating states.
	public init(switcher: FeatureSwitcher) {
		self.switcher = switcher
	}

	/// Resolves and caches the state of every registered feature.
	///
	/// Must be called exactly once. Calling it a second time triggers an assertion failure.
	/// - Returns: `self`, for chaining.
	@discardableResult
	public func bootstrap() async throws -> Self {
		guard !isReady else {
			assertionFailure("FeatureManager has already been bootstrapped")
			return self
		}

		states = try await switcher.generateState(for: features)
		return self
	}

	/// Registers a feature type so its state will be resolved during ``bootstrap()``.
	/// - Parameter type: The ``Feature`` type to register.
	/// - Returns: `self`, for chaining.
	@discardableResult
	public func register<F: Feature>(_ type: F.Type) -> Self {
		features.append(type)
		return self
	}

	/// Returns the resolved state of the given feature, or `nil` if unknown.
	/// - Parameter featureType: The ``Feature`` type to query.
	/// - Returns: The resolved state, or the default one.
	public func state<F: Feature>(of feature: F.Type) -> F.State {
		assert(isReady, "FeatureManager has not been bootstrapped")
		assert(
			features.contains { $0.identifier == F.identifier },
			"Feature \(F.identifier) has not been registered"
		)
		return states?[F.identifier] as? F.State ?? .default
	}

	/// Convenience for boolean features: returns `true` when the state is ``BooleanState/enabled``.
	/// - Parameter featureType: A ``Feature`` whose state type is ``BooleanState``.
	public func isEnabled<F: Feature>(_ featureType: F.Type) -> Bool where F.State == BooleanState {
		return state(of: featureType) == .enabled
	}
}

extension FeatureManager {
	/// Lightweight log metadata containing each registered feature and its current state identifier.
	///
	/// Each entry maps a feature's ``Feature/identifier`` to the resolved state's
	/// ``FeatureState/identifier``, or `"<unknown>"` when the manager has not yet
	/// been bootstrapped.
	public var logMetadata: Logger.Metadata {
		var metaFeatures: Logger.Metadata = [:]
		for feature in features {
			metaFeatures[feature.identifier] = .string(
				isReady
					? (states![feature.identifier]?.identifier ?? "<none>")
					: "<unknown>"
			)
		}

		return metaFeatures
	}

	/// Comprehensive log metadata describing the full state of this manager.
	///
	/// Unlike ``logMetadata``, which only lists feature states, this property
	/// includes additional diagnostic information:
	/// - `isReady` – Whether ``bootstrap()`` has been called.
	/// - `switcher` – The concrete switcher type and its own ``FeatureSwitcher/logMetadata``.
	/// - `features` – Each registered feature's ``Feature/identifier`` mapped to
	///   its resolved ``FeatureState/identifier``, or `"<unknown>"` before bootstrapping.
	public var logCompleteMetadata: Logger.Metadata {
		var metadata: Logger.Metadata = [
			"isReady": isReady ? "true" : "false"
		]

		metadata["switcher"] = .dictionary([
			"type": .string(String(describing: type(of: switcher)))
		].merging(switcher.logMetadata, uniquingKeysWith: { $1 }))

		var metaFeatures: Logger.Metadata = [:]
		for feature in features {
			metaFeatures[feature.identifier] = .string(
				states != nil
					? (states![feature.identifier]?.identifier ?? "<none>")
					: "<unknown>"
			)
		}
		metadata["features"] = .dictionary(metaFeatures)

		return metadata
	}
}
