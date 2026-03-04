//
//  FeatureStateTests.swift
//  PyanFeatureSwitcher
//
//  Created by Perceval Archimbaud on 04/03/2026.
//

import Testing
import PyanFeatureSwitcher

@Suite("FeatureState")
struct FeatureStateTests {
	// MARK: - Custom FeatureState

	@Suite("Custom FeatureState with RawRepresentable conformance")
	struct CustomFeatureStateTests {

		@Test("identifier returns raw value for custom state")
		func customStateIdentifier() {
			#expect(ProfilePosition.State.top.identifier == "top")
			#expect(ProfilePosition.State.middle.identifier == "middle")
			#expect(ProfilePosition.State.bottom.identifier == "bottom")
		}
	}
}
