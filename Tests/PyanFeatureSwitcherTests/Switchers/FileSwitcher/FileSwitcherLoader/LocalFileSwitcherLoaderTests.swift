//
//  LocalFileSwitcherLoaderTests.swift
//  PyanFeatureSwitcher
//
//  Created by Perceval Archimbaud on 04/03/2026.
//

import Testing
import Foundation
import PyanFeatureSwitcher

@Suite("LocalFileSwitcherLoader")
struct LocalFileSwitcherLoaderTests {

	@Test("loads data from a valid local file URL")
	func loadsDataFromValidURL() async throws {
		let url = try #require(
			Bundle.module.url(forResource: "BasicFeatureStates", withExtension: "plist")
		)

		let loader = LocalFileSwitcherLoader(path: url)
		let data = try await loader.loadData(filters: [])

		#expect(!data.isEmpty)

		let filteredData = try await loader.loadData(filters: ["Debug"])
		#expect(!filteredData.isEmpty)
	}

	@Test("throws when file does not exist")
	func throwsForMissingFile() async {
		let url = URL(fileURLWithPath: "/nonexistent/path/file.plist")
		let loader = LocalFileSwitcherLoader(path: url)

		await #expect(throws: (any Error).self) {
			_ = try await loader.loadData(filters: [])
		}
	}
}
