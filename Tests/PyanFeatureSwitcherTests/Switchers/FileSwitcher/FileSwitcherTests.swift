//
//  FileSwitcherTests.swift
//  PyanFeatureSwitcher
//
//  Created by Perceval Archimbaud on 04/03/2026.
//

import Testing
import Foundation
import PyanFeatureSwitcher

@Suite("FileSwitcher")
struct FileSwitcherTests {

	@Suite("Constant states")
	struct ConstantStateTests {

		@Test("generates constant states from parser output")
		func generatesConstantStates() async throws {
			let parser = MockFileSwitcherParser()
			parser.result = .success([
				"UseOnboarding": .constant("enabled"),
				"ProfilePosition": .constant("top")
			])

			let switcher = FileSwitcher(
				loader: StubFileSwitcherLoader(),
				parser: parser
			)

			let states = try await switcher.generateState(
				for: [UseOnboarding.self, ProfilePosition.self]
			)

			#expect(states["UseOnboarding"] as? BooleanState == .enabled)
			#expect(states["ProfilePosition"] as? ProfilePosition.State == .top)
		}
	}

	// MARK: - Randomized states

	@Suite("Randomized states")
	struct RandomizedStateTests {

		@Test("generates randomized states from parser output")
		func generatesRandomizedStates() async throws {
			let parser = MockFileSwitcherParser()
			parser.result = .success([
				"UseOnboarding": .randomized(["enabled": 0.5, "disabled": 0.5]),
				"ProfilePosition": .randomized(["top": 0.2, "middle": 0.2, "bottom": 0.6])
			])

			let switcher = FileSwitcher(
				loader: StubFileSwitcherLoader(),
				parser: parser
			)

			let states = try await switcher.generateState(
				for: [UseOnboarding.self, ProfilePosition.self]
			)

			#expect(states["UseOnboarding"] is BooleanState)
			#expect(states["ProfilePosition"] is ProfilePosition.State)
		}
	}

	// MARK: - Parser errors

	@Suite("Parser error forwarding")
	struct ParserErrorTests {

		@Test("throws parser error when parser fails")
		func throwsParserError() async throws {
			let parser = MockFileSwitcherParser()
			parser.result = .failure(FileSwitcherParserError.unexpectedKeyPath(path: "test"))

			let switcher = FileSwitcher(
				loader: StubFileSwitcherLoader(),
				parser: parser
			)

			await #expect(throws: FileSwitcherParserError.self) {
				_ = try await switcher.generateState(
					for: [UseOnboarding.self, ProfilePosition.self]
				)
			}
		}
	}

	// MARK: - Load failure recovery

	@Suite("Load failure recovery")
	struct LoadFailureRecoveryTests {

		@Test("recovers from cache when loader fails and recovery is allowed")
		func recoversFromCacheOnLoadFailure() async throws {
			let cache = InMemorySwitcherCache()
			cache.persist(BooleanState.enabled, key: UseOnboarding.self)
			cache.persist(ProfilePosition.State.bottom, key: ProfilePosition.self)

			let options = try FileSwitcher.Options(
				filters: [],
				cache: cache,
				allowLoadFailureRecovery: true
			)

			let switcher = FileSwitcher(
				loader: FailingFileSwitcherLoader(),
				parser: MockFileSwitcherParser(),
				options: options
			)

			let states = try await switcher.generateState(
				for: [UseOnboarding.self, ProfilePosition.self]
			)

			#expect(states["UseOnboarding"] as? BooleanState == .enabled)
			#expect(states["ProfilePosition"] as? ProfilePosition.State == .bottom)
		}

		@Test("throws when loader fails and recovery is disabled")
		func throwsWhenRecoveryDisabled() async throws {
			let options = try FileSwitcher.Options(
				filters: [],
				cache: InMemorySwitcherCache(),
				allowLoadFailureRecovery: false
			)

			let switcher = FileSwitcher(
				loader: FailingFileSwitcherLoader(),
				parser: MockFileSwitcherParser(),
				options: options
			)

			await #expect(throws: FailingFileSwitcherLoader.LoadError.self) {
				_ = try await switcher.generateState(
					for: [UseOnboarding.self]
				)
			}
		}

		@Test("throws when loader fails, recovery is allowed, but cache is empty")
		func throwsWhenRecoveryAllowedButCacheEmpty() async throws {
			let options = try FileSwitcher.Options(
				filters: [],
				cache: InMemorySwitcherCache(),
				allowLoadFailureRecovery: true
			)

			let switcher = FileSwitcher(
				loader: FailingFileSwitcherLoader(),
				parser: MockFileSwitcherParser(),
				options: options
			)

			await #expect(throws: FailingFileSwitcherLoader.LoadError.self) {
				_ = try await switcher.generateState(
					for: [UseOnboarding.self]
				)
			}
		}

		@Test("succeeds when loader fails, recovery is allowed, and features list is empty")
		func succeedsWhenRecoveryAllowedAndNoFeatures() async throws {
			let options = try FileSwitcher.Options(
				filters: [],
				cache: InMemorySwitcherCache(),
				allowLoadFailureRecovery: true
			)

			let switcher = FileSwitcher(
				loader: FailingFileSwitcherLoader(),
				parser: MockFileSwitcherParser(),
				options: options
			)

			let states = try await switcher.generateState(for: [])

			#expect(states.isEmpty)
		}

		@Test("returns partial cache when some features are cached")
		func returnsPartialCacheOnFailure() async throws {
			let cache = InMemorySwitcherCache()
			cache.persist(BooleanState.enabled, key: UseOnboarding.self)
			// ProfilePosition is NOT cached

			let options = try FileSwitcher.Options(
				filters: [],
				cache: cache,
				allowLoadFailureRecovery: true
			)

			let switcher = FileSwitcher(
				loader: FailingFileSwitcherLoader(),
				parser: MockFileSwitcherParser(),
				options: options
			)

			let states = try await switcher.generateState(
				for: [UseOnboarding.self, ProfilePosition.self]
			)

			#expect(states["UseOnboarding"] as? BooleanState == .enabled)
			#expect(states["ProfilePosition"] == nil)
		}
	}

}
