//
//  FeatureSwitcher.swift
//  PyanFeatureSwitcher
//
//  Created by Perceval Archimbaud on 04/03/2026.
//

import Foundation
import Logging

/// A strategy that resolves the state of a set of features.
///
/// Implement this protocol to provide custom feature-state resolution
/// logic (e.g. remote configuration, A/B testing service, etc.).
///
/// The library ships with four built-in conformances:
/// - ``ConstantSwitcher`` — hard-coded states
/// - ``RandomSwitcher`` — probability-based random assignment
/// - ``FileSwitcher`` — file-driven configuration (e.g. property lists)
/// - ``MultiplexSwitcher`` — composes multiple switchers into one
///
/// Switchers can be composed using ``MultiplexSwitcher`` directly
/// or through the convenience ``multiplex(_:)`` extension.
public protocol FeatureSwitcher: Sendable {
	/// Generates a state for each feature in the given list.
	/// - Parameter features: The feature types to resolve.
	/// - Returns: A dictionary mapping feature identifiers to their resolved states.
	func generateState(for features: [any Feature.Type]) async throws -> [String: any FeatureState]

	/// Structured metadata describing this switcher's configuration.
	///
	/// ``FeatureManager`` includes this metadata in its own
	/// ``FeatureManager/logMetadata`` so that a single dictionary
	/// captures the full feature-flag setup for logging or diagnostics.
	///
	/// The default implementation returns an empty dictionary.
	/// Override it in your conforming type to expose configuration
	/// details (URLs, cache type, filter sets, etc.).
	var logMetadata: Logger.Metadata { get }
}

public extension FeatureSwitcher {
	var logMetadata: Logger.Metadata { [:] }
}
