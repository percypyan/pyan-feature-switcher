//
//  SwitcherMemory.swift
//  PyanFeatureSwitcher
//
//  Created by Perceval Archimbaud on 05/03/2026.
//

/// A cache that persists and retrieves resolved feature states.
///
/// Switchers like ``RandomSwitcher`` and ``FileSwitcher`` use a cache
/// to ensure that a feature's state remains stable across launches.
///
/// The library provides two built-in implementations:
/// - ``InMemorySwitcherCache`` — lives only for the process lifetime
/// - ``UserDefaultsSwitcherCache`` — persists across launches (Apple platforms)
public protocol SwitcherCache: Sendable {
	/// Stores a resolved state for a feature.
	func persist(_ value: any FeatureState, key type: any Feature.Type, with filters: Set<String>)

	/// Loads a previously persisted state, or `nil` if none exists.
	func load(for type: any Feature.Type, with filters: Set<String>) -> (any FeatureState)?
}

public extension SwitcherCache {
	func persist(_ value: any FeatureState, key type: any Feature.Type) {
		persist(value, key: type, with: [])
	}

	func load(for type: any Feature.Type) -> (any FeatureState)? {
		return load(for: type, with: [])
	}
}
