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
/// Requesting a feature state before bootstrap will cause a `precondition`failure.
@Observable
public final class FeatureManager: Sendable {
	@ObservationIgnored
	nonisolated(unsafe) private var states: [String: any FeatureState]? = nil

	@ObservationIgnored
	nonisolated(unsafe) internal private(set) var features: [any Feature.Type] = []

	/// The switcher responsible for resolving each registered feature's state during ``bootstrap()``.
	internal let switcher: FeatureSwitcher

	/// Indicates if this manager ready to use.
	@MainActor public var isReady: Bool = false
	/// Copy the ``isReady`` property but let us access it from outside the main thread safely and quickly.
	/// The duplication allow us to ensure both observability and fast thread-safety, the cost is worthing it.
	private let __isReady: Atomic<Bool> = .init(false)

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
	@MainActor
	public func bootstrap() async throws -> Self {
		guard !__isReady.load(ordering: .acquiring) else {
			assertionFailure("FeatureManager has already been bootstrapped")
			return self
		}
		states = try await switcher.generateState(for: features)
		isReady = true
		__isReady.store(true, ordering: .releasing)
		return self
	}

	/// Registers a feature type so its state will be resolved during ``bootstrap()``.
	/// - Parameter type: The ``Feature`` type to register.
	/// - Returns: `self`, for chaining.
	@discardableResult
	@MainActor
	public func register<F: Feature>(_ type: F.Type) -> Self {
		guard !__isReady.load(ordering: .acquiring) else {
			assertionFailure("FeatureManager has already been bootstrapped")
			return self
		}
		assert(
			!features.contains(where: { $0.identifier == F.identifier }),
			"Feature \(F.identifier) as already been registered"
		)
		features.append(type)
		return self
	}

	/// Returns the resolved state of the given feature, or `nil` if unknown.
	/// - Parameter feature: The ``Feature`` type to query.
	/// - Returns: The resolved state, or the default one.
	public func state<F: Feature>(of feature: F.Type) -> F.State {
		precondition(__isReady.load(ordering: .acquiring), "FeatureManager has not been bootstrapped")
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
	///
	/// > Info: Logging those metadata in a background thread at the same time the manager is being
	/// boostrapped on the main thread is undefined behavior.
	public var logMetadata: Logger.Metadata {
		let isReady = __isReady.load(ordering: .acquiring)
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
	///
	/// > Info: Logging those metadata in a background thread at the same time the manager is being
	/// boostrapped on the main thread is undefined behavior.
	public var logCompleteMetadata: Logger.Metadata {
		var metadata: Logger.Metadata = [
			"isReady": __isReady.load(ordering: .acquiring) ? "true" : "false"
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

extension FeatureManager {
	@MainActor
	internal func synchronousBootstrap() {
		guard !__isReady.load(ordering: .acquiring) else {
			assertionFailure("FeatureManager has already been bootstrapped")
			return
		}
		guard let switcher = switcher as? ConstantSwitcher else {
			assertionFailure("Unexpected switcher type for synchronous bootstrap")
			return
		}
		states = switcher.generateState(for: features)
		isReady = true
		__isReady.store(true, ordering: .releasing)
	}
}
