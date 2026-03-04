//
//  FeatureManagerTests.swift
//  PyanFeatureSwitcher
//
//  Created by Perceval Archimbaud on 04/03/2026.
//

import Testing
import PyanFeatureSwitcher

@Suite("FeatureManager")
struct FeatureManagerTests {

	// MARK: - Registration & bootstrap

	@Test("bootstrap passes registered features to switcher")
	func bootstrapPassesFeatures() async throws {
		let spy = SpyFeatureSwitcher()
		let manager = FeatureManager(switcher: spy)
			.register(UseOnboarding.self)
			.register(ProfilePosition.self)

		try await manager.bootstrap()

		#expect(spy.receivedIdentifiers == ["UseOnboarding", "ProfilePosition"])
	}

	// MARK: - State retrieval

	@Test("state(of:) returns matching state after bootstrap")
	func stateReturnsValue() async throws {
		let manager = FeatureManager(
			switcher: ConstantSwitcher()
				.constant(UseOnboarding.self, enabled: true)
				.constant(ProfilePosition.self, state: .middle)
		)
		.register(UseOnboarding.self)
		.register(ProfilePosition.self)

		try await manager.bootstrap()

		#expect(manager.state(of: UseOnboarding.self) == .enabled)
		#expect(manager.state(of: ProfilePosition.self) == .middle)
	}

	// MARK: - isEnabled

	@Test("isEnabled returns true when state is enabled")
	func isEnabledTrue() async throws {
		let manager = FeatureManager(
			switcher: ConstantSwitcher()
				.constant(UseOnboarding.self, enabled: true)
		)
		.register(UseOnboarding.self)

		try await manager.bootstrap()

		#expect(manager.isEnabled(UseOnboarding.self))
	}

	@Test("isEnabled returns false when state is disabled")
	func isEnabledFalse() async throws {
		let manager = FeatureManager(
			switcher: ConstantSwitcher()
				.constant(UseOnboarding.self, enabled: false)
		)
		.register(UseOnboarding.self)

		try await manager.bootstrap()

		#expect(!manager.isEnabled(UseOnboarding.self))
	}

	@Test("isEnabled returns false when feature has no state")
	func isEnabledFalseWhenMissing() async throws {
		let manager = FeatureManager(
			switcher: ConstantSwitcher()
		)
		.register(UseOnboarding.self)

		try await manager.bootstrap()

		#expect(!manager.isEnabled(UseOnboarding.self))
	}

	@Test("Generation of logMetadata")
	func shouldReturnInfoAboutManagerState() async throws {
		let manager = FeatureManager(
			switcher: ConstantSwitcher()
				.constant(ProfilePosition.self, state: .top)
		)

		#expect(manager.logMetadata == [
			"isReady": "false",
			"switcher": ["type": "PyanFeatureSwitcher.ConstantSwitcher"],
			"features": [:]
		])

		manager
			.register(UseOnboarding.self)
			.register(ProfilePosition.self)

		#expect(manager.logMetadata == [
			"isReady": "false",
			"switcher": ["type": "PyanFeatureSwitcher.ConstantSwitcher"],
			"features": [
				"UseOnboarding": "<unknown>",
				"ProfilePosition": "<unknown>"
			]
		])

		try await manager.bootstrap()

		#expect(manager.logMetadata == [
			"isReady": "true",
			"switcher": ["type": "PyanFeatureSwitcher.ConstantSwitcher"],
			"features": [
				"UseOnboarding": "<none>",
				"ProfilePosition": "top"
			]
		])

		let switcher = RandomSwitcher()
		let manager2 = FeatureManager(switcher: switcher)
		#expect({
			if case .dictionary(let dict) = manager2.logMetadata["switcher"] {
				return dict["type"] == .string(String(describing: switcher))
			}
			return false
		}())
	}
}
