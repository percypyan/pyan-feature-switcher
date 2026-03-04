//
//  PropertyListFileSwitcherParserTests.swift
//  PyanFeatureSwitcher
//
//  Created by Perceval Archimbaud on 04/03/2026.
//

import Testing
import Foundation
import PyanFeatureSwitcher

@Suite("PropertyListFileSwitcherParser")
struct PropertyListFileSwitcherParserTests {

	private let parser = PropertyListFileSwitcherParser()

	private func loadPlistData(named name: String) throws -> Data {
		let url = try #require(
			Bundle.module.url(forResource: name, withExtension: "plist")
		)
		return try Data(contentsOf: url)
	}

	private func expectConstant(
		_ descriptions: [String: FeatureStateDescription],
		key: String,
		value expected: String
	) {
		guard case .constant(let value) = descriptions[key] else {
			Issue.record("Expected .constant for \(key), got \(String(describing: descriptions[key]))")
			return
		}
		#expect(value == expected)
	}

	// MARK: - Basic parsing

	@Test("parses constant boolean and string states")
	func parsesBasicStates() throws {
		let data = try loadPlistData(named: "BasicFeatureStates")

		let descriptions = try parser.extractStateDescription(
			from: data,
			for: [UseOnboarding.self, ProfilePosition.self],
			filters: [],
			categories: nil
		)

		expectConstant(descriptions, key: "UseOnboarding", value: "enabled")
		expectConstant(descriptions, key: "ProfilePosition", value: "top")
	}

	// MARK: - Build configuration filtering

	@Test("resolves state for matching build config flag")
	func resolvesBuildConfigFlag() throws {
		let data = try loadPlistData(named: "BuildConfigFiltersFeatureStates")

		let descriptions = try parser.extractStateDescription(
			from: data,
			for: [ProfilePosition.self],
			filters: ["Debug"],
			categories: nil
		)

		expectConstant(descriptions, key: "ProfilePosition", value: "top")
	}

	@Test("resolves state for alternative build config flag")
	func resolvesAlternativeBuildConfigFlag() throws {
		let data = try loadPlistData(named: "BuildConfigFiltersFeatureStates")

		let descriptions = try parser.extractStateDescription(
			from: data,
			for: [ProfilePosition.self],
			filters: ["Release"],
			categories: nil
		)

		expectConstant(descriptions, key: "ProfilePosition", value: "bottom")
	}

	@Test("resolves nested build config flags")
	func resolvesNestedBuildConfigFlags() throws {
		let data = try loadPlistData(named: "BuildConfigFiltersFeatureStates")

		let descriptions = try parser.extractStateDescription(
			from: data,
			for: [UseOnboarding.self],
			filters: ["tvOS", "Debug"],
			categories: nil
		)

		expectConstant(descriptions, key: "UseOnboarding", value: "disabled")
	}

	// MARK: - Randomized states

	@Test("parses randomized state descriptions with probabilities")
	func parsesRandomizedStates() throws {
		let data = try loadPlistData(named: "RandomizedFeatureStates")

		let descriptions = try parser.extractStateDescription(
			from: data,
			for: [ProfilePosition.self],
			filters: [],
			categories: nil
		)

		guard case .randomized(let config) = descriptions["ProfilePosition"] else {
			Issue.record("Expected randomized description for ProfilePosition")
			return
		}

		#expect(config["top"] == 0.2)
		#expect(config["bottom"] == 0.6)
		#expect(config["middle"] == 0.2)
	}

	@Test("parses partial randomized config")
	func parsesPartialRandomizedConfig() throws {
		let data = try loadPlistData(named: "RandomizedFeatureStates")

		let descriptions = try parser.extractStateDescription(
			from: data,
			for: [UseOnboarding.self],
			filters: [],
			categories: nil
		)

		guard case .randomized(let config) = descriptions["UseOnboarding"] else {
			Issue.record("Expected randomized description for UseOnboarding")
			return
		}

		#expect(config["enabled"] == 0.2)
		#expect(config["disabled"] == nil)
	}

	// MARK: - Categories (allowed build configuration flags)

	@Test("throws unexpectedKeyPath for unknown keys when categories are set")
	func throwsForUnknownKeys() throws {
		let data = try loadPlistData(named: "BuildConfigFiltersFeatureStates")

		#expect(throws: FileSwitcherParserError.self) {
			_ = try parser.extractStateDescription(
				from: data,
				for: [UseOnboarding.self, ProfilePosition.self],
				filters: ["Debug"],
				categories: [.exclusive(["Debug"])]
			)
		}
	}

	@Test("does not throw when all keys are within categories")
	func doesNotThrowWithValidCategories() throws {
		let data = try loadPlistData(named: "BuildConfigFiltersFeatureStates")

		#expect(throws: Never.self) {
			_ = try parser.extractStateDescription(
				from: data,
				for: [UseOnboarding.self, ProfilePosition.self],
				filters: ["Debug", "iOS"],
				categories: [
					.exclusive(["Debug", "Release"]),
					.exclusive(["iOS", "tvOS"])
				]
			)
		}
	}

	// MARK: - Invalid data

	@Test("throws invalidData for non-plist data")
	func throwsForInvalidData() {
		let invalidData = Data("not a plist".utf8)

		#expect(throws: FileSwitcherParserError.self) {
			_ = try parser.extractStateDescription(
				from: invalidData,
				for: [UseOnboarding.self],
				filters: [],
				categories: nil
			)
		}
	}

	// MARK: - Empty features list

	@Test("returns empty descriptions when no features requested")
	func emptyFeaturesReturnsEmpty() throws {
		let data = try loadPlistData(named: "BasicFeatureStates")

		let descriptions = try parser.extractStateDescription(
			from: data,
			for: [],
			filters: [],
			categories: nil
		)

		#expect(descriptions.isEmpty)
	}
}
