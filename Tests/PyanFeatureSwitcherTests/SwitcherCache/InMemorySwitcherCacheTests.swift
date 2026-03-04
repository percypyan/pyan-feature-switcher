//
//  InMemorySwitcherCacheTests.swift
//  PyanFeatureSwitcher
//
//  Created by Perceval Archimbaud on 06/03/2026.
//

import Testing
@testable import PyanFeatureSwitcher

enum TestableSwitcherCache {
	case inMemory
	case userDefaults

	func new() -> any SwitcherCache {
		return switch self {
		case .inMemory: InMemorySwitcherCache()
		case .userDefaults: UserDefaultsSwitcherCache(userDefaults: MockUserDefaults())
		}
	}
}

@Suite("SwitcherCache implementations")
struct SwitcherCacheImplementationTests {
	static let cachesToTest: [TestableSwitcherCache] = [.inMemory, .userDefaults]

	// MARK: - Persist and Load

	@Test("persists and loads a boolean state", arguments: cachesToTest)
	func persistsAndLoadsBooleanState(cacheToTest: TestableSwitcherCache) {
		let cache = cacheToTest.new()

		cache.persist(BooleanState.enabled, key: UseOnboarding.self)

		let loaded = cache.load(for: UseOnboarding.self)
		#expect(loaded as? BooleanState == .enabled)
	}

	@Test("persists and loads a custom state", arguments: cachesToTest)
	func persistsAndLoadsCustomState(cacheToTest: TestableSwitcherCache) {
		let cache = cacheToTest.new()

		cache.persist(ProfilePosition.State.middle, key: ProfilePosition.self)

		let loaded = cache.load(for: ProfilePosition.self)
		#expect(loaded as? ProfilePosition.State == .middle)
	}

	@Test("overwrites previously persisted state", arguments: cachesToTest)
	func overwritesPreviousState(cacheToTest: TestableSwitcherCache) {
		let cache = cacheToTest.new()

		cache.persist(BooleanState.enabled, key: UseOnboarding.self)
		cache.persist(BooleanState.disabled, key: UseOnboarding.self)

		let loaded = cache.load(for: UseOnboarding.self)
		#expect(loaded as? BooleanState == .disabled)
	}

	@Test("returns nil when no state has been persisted", arguments: cachesToTest)
	func returnsNilForMissingState(cacheToTest: TestableSwitcherCache) {
		let cache = cacheToTest.new()

		let loaded = cache.load(for: UseOnboarding.self)
		#expect(loaded == nil)
	}

	// MARK: - Feature isolation

	@Test("stores states independently per feature", arguments: cachesToTest)
	func storesStatesIndependentlyPerFeature(cacheToTest: TestableSwitcherCache) {
		let cache = cacheToTest.new()

		cache.persist(BooleanState.enabled, key: UseOnboarding.self)
		cache.persist(ProfilePosition.State.bottom, key: ProfilePosition.self)

		#expect(cache.load(for: UseOnboarding.self) as? BooleanState == .enabled)
		#expect(cache.load(for: ProfilePosition.self) as? ProfilePosition.State == .bottom)
	}

	// MARK: - Filters

	@Test("isolates states by filter set", arguments: cachesToTest)
	func isolatesStatesByFilters(cacheToTest: TestableSwitcherCache) {
		let cache = cacheToTest.new()

		cache.persist(BooleanState.enabled, key: UseOnboarding.self, with: ["Debug"])
		cache.persist(BooleanState.disabled, key: UseOnboarding.self, with: ["Release"])

		#expect(cache.load(for: UseOnboarding.self, with: ["Debug"]) as? BooleanState == .enabled)
		#expect(cache.load(for: UseOnboarding.self, with: ["Release"]) as? BooleanState == .disabled)
	}

	@Test("filter-free load does not return filtered state", arguments: cachesToTest)
	func filterFreeLoadDoesNotReturnFilteredState(cacheToTest: TestableSwitcherCache) {
		let cache = cacheToTest.new()

		cache.persist(BooleanState.enabled, key: UseOnboarding.self, with: ["Debug"])

		let loaded = cache.load(for: UseOnboarding.self)
		#expect(loaded == nil)
	}

	@Test("filtered load does not return filter-free state", arguments: cachesToTest)
	func filteredLoadDoesNotReturnFilterFreeState(cacheToTest: TestableSwitcherCache) {
		let cache = cacheToTest.new()

		cache.persist(BooleanState.enabled, key: UseOnboarding.self)

		let loaded = cache.load(for: UseOnboarding.self, with: ["Debug"])
		#expect(loaded == nil)
	}

	@Test("filter order does not affect lookup", arguments: cachesToTest)
	func filterOrderDoesNotAffectLookup(cacheToTest: TestableSwitcherCache) {
		let cache = cacheToTest.new()

		cache.persist(BooleanState.enabled, key: UseOnboarding.self, with: ["B", "A"])

		let loaded = cache.load(for: UseOnboarding.self, with: ["A", "B"])
		#expect(loaded as? BooleanState == .enabled)
	}
}
