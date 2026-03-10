//
//  ConstantSwitcher.swift
//  PyanFeatureSwitcher
//
//  Created by Perceval Archimbaud on 04/03/2026.
//

import Synchronization

/// A switcher that returns hard-coded, predetermined states.
///
/// Use `ConstantSwitcher` when the feature state is known at compile
/// time or determined once at startup.
///
/// ```swift
/// let switcher = ConstantSwitcher()
///     .constant(DarkMode.self, enabled: true)
///     .constant(OnboardingFlow.self, state: .redesigned)
/// ```
public final class ConstantSwitcher: FeatureSwitcher {
	let states = Mutex<[String: any FeatureState]>([:])

	#if DEBUG
	private let isOverridable: Bool

	internal init(overridable: Bool) {
		self.isOverridable = overridable
	}
	#endif

	public convenience init() {
		self.init(overridable: false)
	}

	/// Sets a constant state for the given feature.
	/// - Parameters:
	///   - featureType: The ``Feature`` type.
	///   - state: The state to assign.
	/// - Returns: `self`, for chaining.
	@discardableResult
	public func constant<F: Feature>(_ featureType: F.Type, state: F.State) -> Self {
		return constant(featureType.identifier, state: state)
	}

	/// Sets a boolean feature to enabled or disabled.
	/// - Parameters:
	///   - featureType: A ``Feature`` whose state is ``BooleanState``.
	///   - enabled: Whether the feature should be enabled.
	/// - Returns: `self`, for chaining.
	@discardableResult
	public func constant<F: Feature>(_ featureType: F.Type, enabled: Bool) -> Self where F.State == BooleanState {
		return constant(F.identifier, state: enabled ? BooleanState.enabled : .disabled)
	}

	public func generateState(for features: [any Feature.Type]) -> [String: any FeatureState] {
		return states.withLock { $0 }
	}
}

extension ConstantSwitcher {
	@discardableResult
	func constant(_ identifier: String, state: any FeatureState) -> Self {
		return states.withLock { states in
			guard isOverridable || states[identifier] == nil else {
				assertionFailure("State has already been for feature \(identifier)")
				return self
			}
			states[identifier] = state
			return self
		}
	}
}
