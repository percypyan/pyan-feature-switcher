//
//  LocalFileSwitcherLoader.swift
//  PyanFeatureSwitcher
//
//  Created by Perceval Archimbaud on 04/03/2026.
//

import Foundation

/// A ``FileSwitcherLoader`` that reads data from the local filesystem.
public struct LocalFileSwitcherLoader: FileSwitcherLoader {
	private let path: URL?
	private let factory: (@Sendable (Set<String>) -> URL)?

	/// Creates a loader that reads from the given file URL.
	/// - Parameter path: The local file URL to read from.
	public init(path: URL) {
		self.path = path
		self.factory = nil
	}

	public init(factory: @escaping @Sendable (Set<String>) -> URL) {
		self.path = nil
		self.factory = factory
	}

	public func loadData(filters: Set<String>) throws -> Data {
		guard let url = path ?? factory?(filters) else {
			// Never happens since init options ensure one of `path` or `factory`
			// will always be set.
			preconditionFailure("Cannot retrieve an URL for path.")
		}
		return try Data(contentsOf: url)
	}
}
