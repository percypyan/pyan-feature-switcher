//
//  TestsFixtures.swift
//  PyanFeatureSwitcher
//
//  Created by Perceval Archimbaud on 04/03/2026.
//

import Foundation
import PyanFeatureSwitcher

enum UseOnboarding: Feature {}

enum ProfilePosition: Feature {
	enum State: String, FeatureState {
		case top
		case middle
		case bottom
	}
}

final class SpyFeatureSwitcher: FeatureSwitcher {
	nonisolated(unsafe) var receivedIdentifiers: [String] = []

	func generateState(for features: [any Feature.Type]) async throws -> [String: any FeatureState] {
		receivedIdentifiers = features.map({ $0.identifier })
		return [:]
	}
}
final class MockFileSwitcherParser: FileSwitcherParser {
	nonisolated(unsafe) var result: Result<[String: FeatureStateDescription], Error> = .success([:])

	func extractStateDescription(
		from data: Data,
		for features: [any Feature.Type],
		filters: Set<String>,
		categories: [FileSwitcher.Options.Category]?
	) throws -> [String: FeatureStateDescription] {
		try result.get()
	}
}

struct StubFileSwitcherLoader: FileSwitcherLoader {
	func loadData(filters: Set<String>) async throws -> Data {
		Data()
	}
}

struct FailingFileSwitcherLoader: FileSwitcherLoader {
	enum LoadError: Error {
		case simulatedFailure
	}

	func loadData(filters: Set<String>) async throws -> Data {
		throw LoadError.simulatedFailure
	}
}

final class MockUserDefaults: UserDefaults {
	var defaults: [String: Any] = [:]

	override func set(_ value: Any?, forKey key: String) {
		defaults[key] = value
	}

	override func string(forKey defaultName: String) -> String? {
		return defaults[defaultName] as? String
	}
}
