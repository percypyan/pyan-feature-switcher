//
//  FeatureStateDescription.swift
//  PyanFeatureSwitcher
//
//  Created by Perceval Archimbaud on 04/03/2026.
//

/// Describes how a feature's state should be resolved from a file.
///
/// A ``FileSwitcherParser`` produces these descriptions, which
/// ``FileSwitcher`` then interprets.
public enum FeatureStateDescription {
	/// A fixed state identified by its string identifier.
	case constant(String)
	/// A probability distribution mapping state identifiers to weights (0...1).
	case randomized([String: Double])
}
