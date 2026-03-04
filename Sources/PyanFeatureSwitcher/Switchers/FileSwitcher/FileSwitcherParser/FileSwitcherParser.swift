//
//  FileSwitcherParser.swift
//  PyanFeatureSwitcher
//
//  Created by Perceval Archimbaud on 04/03/2026.
//

import Foundation

/// Errors thrown by ``FileSwitcherParser`` implementations.
public enum FileSwitcherParserError: Error {
	/// The data could not be parsed (e.g. malformed plist).
	case invalidData
	/// An unexpected key was found at the given path.
	case unexpectedKeyPath(path: String)
}

/// A type that extracts ``FeatureStateDescription`` values from raw data.
///
/// Conform to this protocol to support custom file formats.
/// The library ships with ``PropertyListFileSwitcherParser`` for
/// property list files.
public protocol FileSwitcherParser: Sendable {
	/// Parses raw data and returns a description for each recognized feature.
	/// - Parameters:
	///   - data: The raw configuration data.
	///   - features: The registered feature types to look for.
	///   - filters: Active filter keys (e.g. build configuration names).
	///   - categories: Optional category definitions for filter validation.
	/// - Returns: A dictionary mapping feature identifiers to their state descriptions.
	func extractStateDescription(
		from data: Data,
		for features: [any Feature.Type],
		filters: Set<String>,
		categories: [FileSwitcher.Options.Category]?
	) throws -> [String: FeatureStateDescription]
}
