//
//  FeatureSwitcherMultiplexTests.swift
//  PyanFeatureSwitcher
//
//  Created by Perceval Archimbaud on 04/03/2026.
//

import Testing
import PyanFeatureSwitcher

@Suite("FeatureSwitcher+Multiplex")
struct FeatureSwitcherMultiplexTests {

	// MARK: - Static multiplex(_:)

	@Test("static multiplex merges results from all switchers")
	func staticMultiplexMergesResults() async throws {
		let first = ConstantSwitcher()
			.constant(UseOnboarding.self, enabled: true)
		let second = ConstantSwitcher()
			.constant(ProfilePosition.self, state: .bottom)

		let multiplexed = MultiplexSwitcher.multiplex([first, second])

		let states = try await multiplexed.generateState(
			for: [UseOnboarding.self, ProfilePosition.self]
		)

		#expect(states["UseOnboarding"] as? BooleanState == .enabled)
		#expect(states["ProfilePosition"] as? ProfilePosition.State == .bottom)
	}

	@Test("static multiplex: later switcher takes precedence on conflict")
	func staticMultiplexLaterTakesPrecedence() async throws {
		let first = ConstantSwitcher()
			.constant(UseOnboarding.self, enabled: true)
		let second = ConstantSwitcher()
			.constant(UseOnboarding.self, enabled: false)

		let multiplexed = MultiplexSwitcher.multiplex([first, second])

		let states = try await multiplexed.generateState(for: [UseOnboarding.self])

		#expect(states["UseOnboarding"] as? BooleanState == .disabled)
	}

	// MARK: - Instance multiplex(_:)

	@Test("instance multiplex merges results from both switchers")
	func instanceMultiplexMergesResults() async throws {
		let first = ConstantSwitcher()
			.constant(UseOnboarding.self, enabled: true)
		let second = ConstantSwitcher()
			.constant(ProfilePosition.self, state: .bottom)

		let multiplexed = first.multiplex(second)

		let states = try await multiplexed.generateState(
			for: [UseOnboarding.self, ProfilePosition.self]
		)

		#expect(states["UseOnboarding"] as? BooleanState == .enabled)
		#expect(states["ProfilePosition"] as? ProfilePosition.State == .bottom)
	}

	@Test("instance multiplex: self takes precedence over argument on conflict")
	func instanceMultiplexSelfTakesPrecedence() async throws {
		let base = ConstantSwitcher()
			.constant(UseOnboarding.self, enabled: false)
		let added = ConstantSwitcher()
			.constant(UseOnboarding.self, enabled: true)

		// self (base) should win over argument (added)
		let multiplexed = base.multiplex(added)

		let states = try await multiplexed.generateState(for: [UseOnboarding.self])

		#expect(states["UseOnboarding"] as? BooleanState == .disabled)
	}

	@Test("instance multiplex flattens MultiplexSwitcher argument and preserves states")
	func instanceMultiplexFlattensArgument() async throws {
		let a = ConstantSwitcher()
			.constant(UseOnboarding.self, enabled: true)
		let b = ConstantSwitcher()
			.constant(ProfilePosition.self, state: .bottom)
		let nested = MultiplexSwitcher(switchers: [a, b])

		let top = ConstantSwitcher()
		let multiplexed = top.multiplex(nested)

		let states = try await multiplexed.generateState(
			for: [UseOnboarding.self, ProfilePosition.self]
		)

		#expect(states["UseOnboarding"] as? BooleanState == .enabled)
		#expect(states["ProfilePosition"] as? ProfilePosition.State == .bottom)
	}

	@Test("instance multiplex flattens self when self is MultiplexSwitcher")
	func instanceMultiplexFlattensSelf() async throws {
		let a = ConstantSwitcher()
			.constant(UseOnboarding.self, enabled: true)
		let b = ConstantSwitcher()
			.constant(ProfilePosition.self, state: .bottom)
		let selfMultiplex = MultiplexSwitcher(switchers: [a, b])

		let base = ConstantSwitcher()
		let multiplexed = selfMultiplex.multiplex(base)

		let states = try await multiplexed.generateState(
			for: [UseOnboarding.self, ProfilePosition.self]
		)

		#expect(states["UseOnboarding"] as? BooleanState == .enabled)
		#expect(states["ProfilePosition"] as? ProfilePosition.State == .bottom)
	}

	@Test("instance multiplex flattens both sides and preserves precedence")
	func instanceMultiplexFlattensBothSides() async throws {
		let a = ConstantSwitcher()
			.constant(UseOnboarding.self, enabled: true)
		let b = ConstantSwitcher()
			.constant(ProfilePosition.self, state: .top)
		let left = MultiplexSwitcher(switchers: [a, b])

		let c = ConstantSwitcher()
			.constant(ProfilePosition.self, state: .bottom)
		let d = ConstantSwitcher()
		let right = MultiplexSwitcher(switchers: [c, d])

		// left is self (higher priority), right is argument (lower priority)
		let multiplexed = left.multiplex(right)

		let states = try await multiplexed.generateState(
			for: [UseOnboarding.self, ProfilePosition.self]
		)

		#expect(states["UseOnboarding"] as? BooleanState == .enabled)
		// left (self) has .top → should win over right's .bottom
		#expect(states["ProfilePosition"] as? ProfilePosition.State == .top)
	}
}
