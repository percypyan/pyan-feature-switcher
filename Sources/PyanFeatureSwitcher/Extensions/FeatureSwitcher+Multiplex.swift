//
//  FeatureSwitcher+Multiplex.swift
//  PyanFeatureSwitcher
//
//  Created by Perceval Archimbaud on 04/03/2026.
//

public extension FeatureSwitcher {
	/// Combines `self` with another switcher into a ``MultiplexSwitcher``.
	///
	/// The receiver (`self`) takes precedence over the provided switcher.
	/// If either side is already a ``MultiplexSwitcher``, its children
	/// are flattened to avoid unnecessary nesting.
	///
	/// ```swift
	/// let switcher = ConstantSwitcher()
	///     .constant(DarkMode.self, enabled: true)
	///     .multiplex(FileSwitcher.propertyList(path: fileURL))
	/// ```
	///
	/// - Parameter switcher: A switcher whose results serve as the
	///   lower-priority base.
	/// - Returns: A ``MultiplexSwitcher`` merging both sets of results.
	func multiplex(_ switcher: any FeatureSwitcher) -> MultiplexSwitcher {
		var switchers: [any FeatureSwitcher]
		// First add passed switcher (lower priority)
		if let switcher = switcher as? MultiplexSwitcher {
			switchers = switcher.switchers
		} else {
			switchers = [switcher]
		}
		// Last add self (higher priority)
		if let self = self as? MultiplexSwitcher {
			switchers.append(contentsOf: self.switchers)
		} else {
			switchers.append(self)
		}
		return MultiplexSwitcher(switchers: switchers)
	}
}
