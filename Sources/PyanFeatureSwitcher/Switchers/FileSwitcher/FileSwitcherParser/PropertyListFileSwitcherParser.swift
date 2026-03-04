//
//  PropertyListFileSwitcherParser.swift
//  PyanFeatureSwitcher
//
//  Created by Perceval Archimbaud on 04/03/2026.
//

import Foundation

/// A ``FileSwitcherParser`` that reads feature states from a property list.
///
/// The plist structure maps feature identifiers to either a constant
/// state string, a boolean, or a dictionary of state probabilities
/// for randomized assignment.
public struct PropertyListFileSwitcherParser: FileSwitcherParser {
	public init() {}

	public func extractStateDescription(
		from data: Data,
		for features: [any Feature.Type],
		filters: Set<String>,
		categories: [FileSwitcher.Options.Category]?
	) throws -> [String: FeatureStateDescription] {
		let dictionary = try? PropertyListSerialization.propertyList(
			from: data,
			options: [],
			format: nil
		) as? NSDictionary

		guard let dictionary else {
			throw FileSwitcherParserError.invalidData
		}

		var description: [String: FeatureStateDescription] = [:]

		try processContent(
			dictionary,
			features: features,
			filters: filters,
			categories: categories,
			stateDescriptions: &description
		)

		return description
	}

	private func processContent(
		_ plistContent: NSDictionary,
		features: [any Feature.Type],
		filters: Set<String>,
		categories: [FileSwitcher.Options.Category]?,
		stateDescriptions: inout [String: FeatureStateDescription],
		feature: (any Feature.Type)? = nil,
		path: String = ""
	) throws {
		var remainingFeatures = features
		for key in plistContent.allKeys {
			guard let key = key as? String else { continue }
			let subPath = path.isEmpty ? key : "\(path).\(key)"

			// Filtered configurations
			if let index = filters.firstIndex(of: key) {
				let value = plistContent.value(forKey: key)

				// Sub configuration
				if let dictionary = value as? NSDictionary {
					var subFilters = filters
					subFilters.remove(at: index)
					let subCategories = categories?.filter({ !$0.choices.contains(filters[index]) })

					try processContent(
						dictionary,
						features: features,
						filters: subFilters,
						categories: subCategories,
						stateDescriptions: &stateDescriptions,
						feature: feature,
						path: subPath
					)
				// Carried feature state
				} else if let feature {
					if let state = getStateDescription(for: feature, value: value) {
						stateDescriptions[feature.identifier] = .constant(state)
					} else {
						assertionFailure("""
						Invalid value for path \(subPath): received \(String(describing: value)) but one of \
						\(feature.stateType.allCases.compactMap({ ($0 as? any FeatureState)?.identifier })) \
						expected
						""")
					}
				} else {
					assertionFailure("Unexpected value \(String(describing: value)) at path \(subPath)")
				}
			// Feature state
			} else if let index = remainingFeatures.firstIndex(where: { $0.identifier == key }) {
				let newFeature = remainingFeatures[index]
				remainingFeatures.remove(at: index)

				let value = plistContent.value(forKey: newFeature.identifier)

				if let state = getStateDescription(for: newFeature, value: value) {
					stateDescriptions[newFeature.identifier] = .constant(state)
				} else if let dictionary = value as? NSDictionary {
					try processContent(
						dictionary,
						features: features,
						filters: filters,
						categories: categories,
						stateDescriptions: &stateDescriptions,
						feature: newFeature,
						path: subPath
					)
				} else {
					assertionFailure("""
					Invalid value for path \(subPath): received \(String(describing: value)) but one of \
					\(newFeature.stateType.allCases.compactMap({ ($0 as? any FeatureState)?.identifier })) \
					expected
					""")
				}
			} else if
				let feature,
				let stateIdentifier = getStateDescription(for: feature, value: key),
				let probability = plistContent.value(forKey: key) as? NSNumber
			{
				if case .randomized(var randomConfig) = stateDescriptions[feature.identifier] {
					randomConfig[stateIdentifier] = probability.doubleValue
					stateDescriptions[feature.identifier] = .randomized(randomConfig)
				} else {
					stateDescriptions[feature.identifier] = .randomized([stateIdentifier: probability.doubleValue])
				}
			} else { // If no match, we assume this key reference an other build configuration
				guard let categories else { continue }

				if !categories.contains(where: { $0.choices.contains(key) }) {
					throw FileSwitcherParserError.unexpectedKeyPath(path: subPath)
				}
			}
		}
	}

	private func getStateDescription(for type: any Feature.Type, value: Any?) -> String? {
		if let string = value as? String {
			return string
		} else if type.stateType == BooleanState.self, let bool = value as? Bool {
			return bool ? BooleanState.enabled.identifier : BooleanState.disabled.identifier
		}
		return nil
	}
}
