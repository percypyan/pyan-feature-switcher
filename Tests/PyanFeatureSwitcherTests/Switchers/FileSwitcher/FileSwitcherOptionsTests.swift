//
//  FileSwitcherOptionsTests.swift
//  PyanFeatureSwitcher
//
//  Created by Perceval Archimbaud on 05/03/2026.
//

import Testing
import Foundation
import PyanFeatureSwitcher

@Suite("FileSwitcher.Options")
struct FileSwitcherOptionsTests {

	// MARK: - Valid configurations

	@Test("succeeds with no filters and no categories")
	func succeedsWithEmptyFiltersNoCategories() {
		#expect(throws: Never.self) {
			_ = try FileSwitcher.Options(
				filters: [],
				cache: InMemorySwitcherCache()
			)
		}
	}

	@Test("succeeds with filters and no categories")
	func succeedsWithFiltersNoCategories() {
		#expect(throws: Never.self) {
			_ = try FileSwitcher.Options(
				filters: ["Debug"],
				cache: InMemorySwitcherCache()
			)
		}
	}

	@Test("succeeds with one filter per category")
	func succeedsWithOneFilterPerCategory() {
		#expect(throws: Never.self) {
			_ = try FileSwitcher.Options(
				filters: ["Debug", "iOS"],
				categories: [
					.exclusive(["Debug", "Release"]),
					.exclusive(["iOS", "tvOS"])
				],
				cache: InMemorySwitcherCache()
			)
		}
	}

	@Test("succeeds with fewer filters than categories")
	func succeedsWithFewerFiltersThanCategories() {
		#expect(throws: Never.self) {
			_ = try FileSwitcher.Options(
				filters: ["Debug"],
				categories: [
					.exclusive(["Debug", "Release"]),
					.exclusive(["iOS", "tvOS"])
				],
				cache: InMemorySwitcherCache()
			)
		}
	}

	@Test("succeeds with empty filters and categories provided")
	func succeedsWithEmptyFiltersAndCategories() {
		#expect(throws: Never.self) {
			_ = try FileSwitcher.Options(
				filters: [],
				categories: [
					.exclusive(["Debug", "Release"])
				],
				cache: InMemorySwitcherCache()
			)
		}
	}

	// MARK: - conflictingCategories

	@Test("throws conflictingCategories when two categories share a choice")
	func throwsConflictingCategoriesSharedChoice() {
		#expect(throws: FileSwitcher.Options.OptionError.self) {
			_ = try FileSwitcher.Options(
				filters: [],
				categories: [
					.exclusive(["Debug", "Release"]),
					.exclusive(["Debug", "Staging"])
				],
				cache: InMemorySwitcherCache()
			)
		}
	}

	@Test("throws conflictingCategories when categories fully overlap")
	func throwsConflictingCategoriesFullOverlap() {
		#expect(throws: FileSwitcher.Options.OptionError.self) {
			_ = try FileSwitcher.Options(
				filters: [],
				categories: [
					.exclusive(["A", "B"]),
					.exclusive(["A", "B"])
				],
				cache: InMemorySwitcherCache()
			)
		}
	}

	// MARK: - conflictingFilter

	@Test("throws conflictingFilter when two filters belong to the same category")
	func throwsConflictingFilterSameCategory() {
		#expect(throws: FileSwitcher.Options.OptionError.self) {
			_ = try FileSwitcher.Options(
				filters: ["Debug", "Release"],
				categories: [
					.exclusive(["Debug", "Release"])
				],
				cache: InMemorySwitcherCache()
			)
		}
	}

	@Test("throws conflictingFilter with multiple categories when conflict is in one")
	func throwsConflictingFilterMultipleCategories() {
		#expect(throws: FileSwitcher.Options.OptionError.self) {
			_ = try FileSwitcher.Options(
				filters: ["iOS", "tvOS", "Debug"],
				categories: [
					.exclusive(["Debug", "Release"]),
					.exclusive(["iOS", "tvOS"])
				],
				cache: InMemorySwitcherCache()
			)
		}
	}

	// MARK: - unexpectedFilter

	@Test("throws unexpectedFilter when filter is not in any category")
	func throwsUnexpectedFilter() {
		#expect(throws: FileSwitcher.Options.OptionError.self) {
			_ = try FileSwitcher.Options(
				filters: ["Unknown"],
				categories: [
					.exclusive(["Debug", "Release"])
				],
				cache: InMemorySwitcherCache()
			)
		}
	}

	@Test("throws unexpectedFilter when one filter is valid and another is not")
	func throwsUnexpectedFilterMixed() {
		#expect(throws: FileSwitcher.Options.OptionError.self) {
			_ = try FileSwitcher.Options(
				filters: ["Debug", "Unknown"],
				categories: [
					.exclusive(["Debug", "Release"])
				],
				cache: InMemorySwitcherCache()
			)
		}
	}
}
