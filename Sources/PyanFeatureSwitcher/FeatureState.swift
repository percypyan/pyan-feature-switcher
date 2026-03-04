//
//  FeatureState.swift
//  PyanFeatureSwitcher
//
//  Created by Perceval Archimbaud on 04/03/2026.
//

import Foundation

/// A type that describes the possible states of a ``Feature``.
///
/// Conforming types must be `CaseIterable` so that switchers can
/// enumerate all valid states. For `String`-backed enums, the
/// ``identifier`` is provided automatically from the raw value.
///
/// ```swift
/// enum OnboardingVariant: String, FeatureState {
///     case classic
///     case redesigned
///     case experimental
/// }
/// ```
public protocol FeatureState: Sendable, Hashable, CaseIterable {
	/// The default state.
	static var `default`: Self { get }

	/// A unique string identifying this state value.
	var identifier: String { get }
}

public extension FeatureState {
	static var `default`: Self {
		precondition(!allCases.isEmpty, "FeatureState should have at least one case")
		return allCases.first!
	}
}

public extension FeatureState where Self: RawRepresentable, RawValue == String {
	var identifier: String { rawValue }
}

/// A simple enabled/disabled state used as the default ``Feature/State``.
public enum BooleanState: String, FeatureState {
	case enabled
	case disabled

	public static let `default`: Self = .disabled
}
