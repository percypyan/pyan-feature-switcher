//
//  ConstantFeatureManagerFactory.swift
//  PyanFeatureSwitcher
//
//  Created by Perceval Archimbaud on 09/03/2026.
//

/// A convenience factory that builds a fully bootstrapped ``FeatureManager``
/// backed by a ``ConstantSwitcher``.
///
/// Use `ConstantFeatureManagerFactory` when you need a ready-to-use manager
/// with hard-coded feature states — typically in SwiftUI previews, unit tests,
/// or other contexts where an asynchronous ``FeatureManager/bootstrap()`` call
/// is impractical.
///
/// ```swift
/// let manager = ConstantFeatureManagerFactory()
///     .constant(DarkMode.self, enabled: true)
///     .constant(OnboardingFlow.self, state: .redesigned)
///     .createBootstrappedManager()
///
/// manager.isEnabled(DarkMode.self) // true
/// ```
///
/// The factory registers each feature, configures its state on the
/// underlying ``ConstantSwitcher``, and performs a synchronous bootstrap
/// so the returned manager is immediately queryable.
///
/// You can also use ``multiplexed(with:)`` to layer the factory's
/// constant states on top of an existing ``FeatureManager``, producing a
/// new manager whose switcher combines both sources.
public final class ConstantFeatureManagerFactory {
	private var features: [any Feature.Type] = []
	private let switcher: ConstantSwitcher

	#if DEBUG
	/// Creates a new factory.
	///
	/// - Parameter isOverridable: When `true`, calling ``constant(_:state:)``
	///   or ``constant(_:enabled:)`` with the same feature type replaces
	///   the previously set state instead of triggering an assertion. Defaults to `false`.
	///
	/// > important: Only available in **Debug** builds.
	public init(isOverridable: Bool = false) {
		switcher = ConstantSwitcher(overridable: isOverridable)
	}
	#else
	/// Creates a new factory.
	public init() {
		switcher = ConstantSwitcher()
	}
	#endif

	/// Pins a feature to the given state.
	///
	/// If the same feature type is added more than once, the most recent
	/// state wins.
	///
	/// - Parameters:
	///   - featureType: The ``Feature`` type to configure.
	///   - state: The state to assign.
	/// - Returns: `self`, for chaining.
	@discardableResult
	public func constant<F: Feature>(_ featureType: F.Type, state: F.State) -> Self {
		if !features.contains(where: { $0.identifier == F.identifier }) {
			features.append(featureType)
		}
		switcher.constant(featureType, state: state)
		return self
	}

	/// Pins a boolean feature to enabled or disabled.
	///
	/// Convenience overload for features whose state type is ``BooleanState``.
	///
	/// - Parameters:
	///   - featureType: A ``Feature`` whose state is ``BooleanState``.
	///   - enabled: Whether the feature should be enabled.
	/// - Returns: `self`, for chaining.
	@discardableResult
	public func constant<F: Feature>(_ featureType: F.Type, enabled: Bool) -> Self where F.State == BooleanState {
		if !features.contains(where: { $0.identifier == F.identifier }) {
			features.append(featureType)
		}
		switcher.constant(featureType, enabled: enabled)
		return self
	}

	/// Creates a ``FeatureManager`` that is already bootstrapped and ready to query.
	///
	/// This method registers all features that were added via ``constant(_:state:)``
	/// or ``constant(_:enabled:)``, then performs a synchronous bootstrap using the
	/// underlying ``ConstantSwitcher``.
	///
	/// - Returns: A fully bootstrapped ``FeatureManager``.
	public func createBootstrappedManager() -> FeatureManager {
		let manager = FeatureManager(switcher: switcher)
		features.forEach { manager.register($0) }
		manager.synchronousBootstrap()
		return manager
	}

	/// Creates a new ``FeatureManager`` that combines the factory's constant
	/// states with the features and switcher of an existing manager.
	///
	/// The factory's ``ConstantSwitcher`` takes precedence: any feature
	/// configured here overrides the state resolved by `other`'s switcher.
	/// Features registered in `other` that are not present in the factory
	/// are carried over automatically.
	///
	/// The returned manager is **not** bootstrapped — call
	/// ``FeatureManager/bootstrap()`` before querying state.
	///
	/// ```swift
	/// let manager = ConstantFeatureManagerFactory()
	///     .constant(DarkMode.self, enabled: false)
	///     .multiplexed(with: existingManager)
	///
	/// try await manager.bootstrap()
	/// ```
	///
	/// - Parameter other: An existing ``FeatureManager`` whose switcher
	///   and registered features are merged with the factory's configuration.
	/// - Returns: A new, non-bootstrapped ``FeatureManager``.
	public func multiplexed(with other: FeatureManager) -> FeatureManager {
		let manager = FeatureManager(switcher: switcher.multiplex(other.switcher))
		for feature in other.features {
			manager.register(feature)
		}
		for feature in features {
			guard !manager.features.contains(where: { $0.identifier == feature.identifier }) else {
				continue
			}
			manager.register(feature)
		}
		return manager
	}
}
