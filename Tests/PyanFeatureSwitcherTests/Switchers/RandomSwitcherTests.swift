//
//  RandomSwitcherTests.swift
//  PyanFeatureSwitcher
//
//  Created by Perceval Archimbaud on 04/03/2026.
//

import Synchronization
import Testing
@testable import PyanFeatureSwitcher

@Suite("RandomSwitcher")
struct RandomSwitcherTests {

	@Test("generates a state for each registered feature")
	func generatesStateForEachFeature() async throws {
		let switcher = RandomSwitcher(randomGenerator: { _ in 0.5 })

		let states = switcher.generateState(
			for: [UseOnboarding.self, ProfilePosition.self]
		)

		#expect(states.count == 2)
		#expect(states["UseOnboarding"] is BooleanState)
		#expect(states["ProfilePosition"] is ProfilePosition.State)
	}

	@Test("returns empty dictionary when no features provided")
	func emptyFeaturesReturnsEmpty() async throws {
		let switcher = RandomSwitcher(randomGenerator: { _ in 0.5 })

		let states = switcher.generateState(for: [])

		#expect(states.isEmpty)
	}

	// MARK: - Probability distribution

	@Test("selects first state when random is below its probability")
	func selectsFirstState() async throws {
		// BooleanState.allCases = [.enabled, .disabled]
		// With equal 0.5/0.5 split, random < 0.5 should select .enabled
		let switcher = RandomSwitcher(randomGenerator: { _ in 0.1 })
			.probabilities(for: UseOnboarding.self, [.enabled: 0.5, .disabled: 0.5])

		let states = switcher.generateState(for: [UseOnboarding.self])

		#expect(states["UseOnboarding"] as? BooleanState == .enabled)
	}

	@Test("selects second state when random exceeds first probability")
	func selectsSecondState() async throws {
		let switcher = RandomSwitcher(randomGenerator: { _ in 0.6 })
			.probabilities(for: UseOnboarding.self, [.enabled: 0.5, .disabled: 0.5])

		let states = switcher.generateState(for: [UseOnboarding.self])

		#expect(states["UseOnboarding"] as? BooleanState == .disabled)
	}

	@Test("selects top state for low random value")
	func selectsTopState() async throws {
		let switcher = RandomSwitcher(randomGenerator: { _ in 0.0 })
			.probabilities(
				for: ProfilePosition.self,
				[.top: 0.33, .middle: 0.34, .bottom: 0.33]
			)

		let states = switcher.generateState(for: [ProfilePosition.self])

		#expect(states["ProfilePosition"] as? ProfilePosition.State == .top)
	}

	@Test("selects middle state for mid random value")
	func selectsMiddleState() async throws {
		let switcher = RandomSwitcher(randomGenerator: { _ in 0.4 })
			.probabilities(
				for: ProfilePosition.self,
				[.top: 0.33, .middle: 0.34, .bottom: 0.33]
			)

		let states = switcher.generateState(for: [ProfilePosition.self])

		#expect(states["ProfilePosition"] as? ProfilePosition.State == .middle)
	}

	@Test("selects bottom state for high random value")
	func selectsBottomState() async throws {
		let switcher = RandomSwitcher(randomGenerator: { _ in 0.8 })
			.probabilities(
				for: ProfilePosition.self,
				[.top: 0.33, .middle: 0.34, .bottom: 0.33]
			)

		let states = switcher.generateState(for: [ProfilePosition.self])

		#expect(states["ProfilePosition"] as? ProfilePosition.State == .bottom)
	}

	// MARK: - Default probabilities

	@Test("distributes equally when no probabilities configured")
	func defaultEqualDistribution() async throws {
		// BooleanState has 2 cases, so default probability = 0.5 each
		// random = 0.1 < 0.5 → first case (.enabled)

		let states = RandomSwitcher(randomGenerator: { _ in 0.49 })
			.generateState(for: [UseOnboarding.self])

		#expect(states["UseOnboarding"] as? BooleanState == .enabled)

		let states2 = RandomSwitcher(randomGenerator: { _ in 0.51 })
			.generateState(for: [UseOnboarding.self])

		#expect(states2["UseOnboarding"] as? BooleanState == .disabled)
	}

	@Test("default distribution selects later case for high random value")
	func defaultDistributionHighRandom() async throws {
		// random = 0.9 > 0.5 → second case (.disabled)
		let switcher = RandomSwitcher(randomGenerator: { _ in 0.9 })

		let states = switcher.generateState(for: [UseOnboarding.self])

		#expect(states["UseOnboarding"] as? BooleanState == .disabled)
	}

	// MARK: - Partial definition

	@Test("state without defined probability shares equally what remains", arguments: [
		(0.19, ProfilePosition.State.top),
		(0.21, .middle),
		(0.59, .middle),
		(0.61, .bottom)
	])
	func definedWithoutProbabilityShareEquallyRemains(
		generated: Double,
		expected: ProfilePosition.State
	) async throws {
		let switcher = RandomSwitcher(randomGenerator: { _ in generated })
			.probabilities(
				for: ProfilePosition.self,
				[.top: 0.20]
			)

		let states = switcher.generateState(for: [ProfilePosition.self])

		#expect(states["ProfilePosition"] as? ProfilePosition.State == expected)
	}

	// MARK: - Chaining

	@Test("probabilities returns self for chaining")
	func chainingAPI() async throws {
		let switcher = RandomSwitcher(randomGenerator: { _ in 0.5 })
			.probabilities(for: UseOnboarding.self, [.enabled: 0.5, .disabled: 0.5])
			.probabilities(
				for: ProfilePosition.self,
				[.top: 0.33, .middle: 0.34, .bottom: 0.33]
			)

		let states = switcher.generateState(
			for: [UseOnboarding.self, ProfilePosition.self]
		)

		#expect(states.count == 2)
	}

	// MARK: - Cache

	@Test("persists generated state to cache")
	func persistsStateToCache() async throws {
		let cache = InMemorySwitcherCache()
		let switcher = RandomSwitcher(cache: cache, randomGenerator: { _ in 0.1 })
			.probabilities(for: UseOnboarding.self, [.enabled: 0.5, .disabled: 0.5])

		_ = switcher.generateState(for: [UseOnboarding.self])

		let cached = cache.load(for: UseOnboarding.self)
		#expect(cached as? BooleanState == .enabled)
	}

	@Test("returns cached state on subsequent calls ignoring new random value")
	func returnsCachedStateOnSubsequentCalls() async throws {
		let cache = InMemorySwitcherCache()
		// First call: random 0.1 → .enabled (< 0.5 threshold)
		let switcher = RandomSwitcher(cache: cache, randomGenerator: { _ in 0.1 })
			.probabilities(for: UseOnboarding.self, [.enabled: 0.5, .disabled: 0.5])

		let first = switcher.generateState(for: [UseOnboarding.self])
		#expect(first["UseOnboarding"] as? BooleanState == .enabled)

		// Second call with different random that would normally pick .disabled
		let switcher2 = RandomSwitcher(cache: cache, randomGenerator: { _ in 0.9 })
			.probabilities(for: UseOnboarding.self, [.enabled: 0.5, .disabled: 0.5])

		let second = switcher2.generateState(for: [UseOnboarding.self])
		#expect(second["UseOnboarding"] as? BooleanState == .enabled)
	}

	@Test("does not call random generator when cache has value")
	func skipsRandomGeneratorWhenCached() async throws {
		let cache = InMemorySwitcherCache()
		cache.persist(BooleanState.disabled, key: UseOnboarding.self)

		let generatorCalled = Mutex(false)
		let switcher = RandomSwitcher(cache: cache, randomGenerator: { range in
			generatorCalled.withLock { $0 = true }
			return Double.random(in: range)
		})

		let states = switcher.generateState(for: [UseOnboarding.self])

		#expect(states["UseOnboarding"] as? BooleanState == .disabled)
		#expect(!generatorCalled.withLock { $0 })
	}

	@Test("caches each feature independently")
	func cachesEachFeatureIndependently() async throws {
		let cache = InMemorySwitcherCache()
		cache.persist(BooleanState.disabled, key: UseOnboarding.self)

		// ProfilePosition is not cached, so random generator runs for it
		let switcher = RandomSwitcher(cache: cache, randomGenerator: { _ in 0.0 })
			.probabilities(
				for: UseOnboarding.self,
				[.enabled: 0.5, .disabled: 0.5]
			)
			.probabilities(
				for: ProfilePosition.self,
				[.top: 0.33, .middle: 0.34, .bottom: 0.33]
			)

		let states = switcher.generateState(
			for: [UseOnboarding.self, ProfilePosition.self]
		)

		// UseOnboarding from cache (random generation would have returned .enabled)
		#expect(states["UseOnboarding"] as? BooleanState == .disabled)
		// ProfilePosition freshly generated (random 0.0 → .top)
		#expect(states["ProfilePosition"] as? ProfilePosition.State == .top)
		// ProfilePosition is now also cached
		#expect(cache.load(for: ProfilePosition.self) as? ProfilePosition.State == .top)
	}
}
