//
//  UserDefaultsSwitcherCache.swift
//  PyanFeatureSwitcher
//
//  Created by Perceval Archimbaud on 05/03/2026.
//

#if canImport(Darwin)

import Foundation

/// A ``SwitcherCache`` backed by `UserDefaults`.
///
/// This is the default cache on Apple platforms. States survive
/// app restarts, ensuring users see a consistent experience.
public struct UserDefaultsSwitcherCache: SwitcherCache {
	// Unsafe is fine because UserDefaults is thread-safe
	nonisolated(unsafe) private let userDefaults: UserDefaults

	/// Creates a cache backed by the given `UserDefaults` suite.
	/// - Parameter userDefaults: The defaults database to use. Defaults to `.standard`.
	public init(userDefaults: UserDefaults = .standard) {
		self.userDefaults = userDefaults
	}

	public func persist(_ value: any FeatureState, key type: any Feature.Type, with filters: Set<String>) {
		userDefaults.set(value.identifier, forKey: key(for: type, with: filters))
	}

	public func load(for type: any Feature.Type, with filters: Set<String>) -> (any FeatureState)? {
		guard let value = userDefaults.string(forKey: key(for: type, with: filters)) else {
			return nil
		}
		return type.stateType.allCases
			.first(where: { ($0 as? any FeatureState)?.identifier == value }) as? any FeatureState
	}

	private func key(for type: any Feature.Type, with filters: Set<String>) -> String {
		let filterPrefix = filters.isEmpty ? "" : ".\(filters.sorted().joined(separator: "."))"
		return "PyanFeatureSwitcher.Switcher.SwitcherPersistor\(filterPrefix).\(type.identifier)"
	}
}

#endif
