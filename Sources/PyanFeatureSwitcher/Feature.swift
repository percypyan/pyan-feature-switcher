//
//  Feature.swift
//  PyanFeatureSwitcher
//
//  Created by Perceval Archimbaud on 04/03/2026.
//

import Foundation

/// A type that represents a feature flag in your application.
///
/// Conform to this protocol to define a feature that can be toggled
/// between different states. The default ``State`` is ``BooleanState``,
/// which provides simple enabled/disabled toggling.
///
/// ```swift
/// enum DarkMode: Feature {}
///
/// enum OnboardingFlow: Feature {
///     typealias State = OnboardingVariant
/// }
/// ```
///
/// The ``identifier`` defaults to the type name and is used as the
/// lookup key when resolving state from a ``FeatureSwitcher``.
public protocol Feature: Sendable {
	/// The type of state this feature can be in.
	associatedtype State: FeatureState = BooleanState

	/// A unique string identifying this feature.
	static var identifier: String { get }
}

public extension Feature {
	/// The type name, used as the default identifier.
	static var identifier: String { String(describing: self) }

	/// The metatype of the feature's state, used internally for resolution.
	static var stateType: State.Type { State.self }
}
