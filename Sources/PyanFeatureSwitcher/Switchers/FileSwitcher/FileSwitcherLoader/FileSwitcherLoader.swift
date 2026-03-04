//
//  FileSwitcherLoader.swift
//  PyanFeatureSwitcher
//
//  Created by Perceval Archimbaud on 04/03/2026.
//

import Foundation

/// A type that loads raw configuration data.
///
/// Conform to this protocol to support custom data sources
/// (e.g. remote URLs, encrypted files). The library ships with
/// ``LocalFileSwitcherLoader`` for reading from the local filesystem.
public protocol FileSwitcherLoader: Sendable {
	/// Loads and returns the content as raw data.
	func loadData(filters: Set<String>) async throws -> Data
}
