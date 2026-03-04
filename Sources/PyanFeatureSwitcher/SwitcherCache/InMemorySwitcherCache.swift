//
//  InMemorySwitcherCache.swift
//  PyanFeatureSwitcher
//
//  Created by Perceval Archimbaud on 05/03/2026.
//

import Synchronization

/// A ``SwitcherCache`` that stores feature states in memory.
///
/// States are lost when the process terminates. Useful for testing
/// or when persistence across launches is not needed.
public final class InMemorySwitcherCache: SwitcherCache {
	private let cache = Mutex<[String: String]>([:])

	public init() {}

	public func persist(_ value: any FeatureState, key type: any Feature.Type, with filters: Set<String>) {
		cache.withLock {
			$0[key(for: type, with: filters)] = value.identifier
		}
	}

	public func load(for type: any Feature.Type, with filters: Set<String>) -> (any FeatureState)? {
		let cachedID = cache.withLock {
			$0[key(for: type, with: filters)]
		}
		return type.stateType.allCases.first(where: {
			($0 as? any FeatureState)?.identifier == cachedID
		}) as? any FeatureState
	}

	private func key(for type: any Feature.Type, with filters: Set<String>) -> String {
		let filterPrefix = filters.isEmpty ? "" : "\(filters.sorted().joined(separator: "."))."
		return "\(filterPrefix)\(type)"
	}
}
