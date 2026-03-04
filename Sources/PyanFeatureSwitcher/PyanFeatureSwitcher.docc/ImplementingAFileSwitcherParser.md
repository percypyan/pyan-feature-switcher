# Implementing a FileSwitcherParser

Support custom file formats by conforming to ``FileSwitcherParser``.

## Overview

``FileSwitcher`` delegates the interpretation of raw configuration data
to a ``FileSwitcherParser``. The library ships with
``PropertyListFileSwitcherParser`` for property list files, but you can
add support for any format — JSON, YAML, TOML, or a proprietary
binary layout — by implementing this protocol.

## The Protocol

``FileSwitcherParser`` has a single requirement:

```swift
public protocol FileSwitcherParser {
    func extractStateDescription(
        from data: Data,
        for features: [any Feature.Type],
        filters: Set<String>,
        categories: [FileSwitcher.Options.Category]?
    ) throws -> [String: FeatureStateDescription]
}
```

Your implementation receives:

| Parameter | Description |
|---|---|
| `data` | The raw bytes loaded by a ``FileSwitcherLoader``. |
| `features` | The registered ``Feature`` types to look for. |
| `filters` | Active filter keys (e.g. build configuration names). |
| `categories` | Optional category definitions used to validate filters. |

It must return a dictionary mapping feature identifiers to
``FeatureStateDescription`` values.

## FeatureStateDescription

``FeatureStateDescription`` tells ``FileSwitcher`` *how* to resolve a
feature's state:

```swift
public enum FeatureStateDescription {
    case constant(String)
    case randomized([String: Double])
}
```

- **`constant`** — a fixed state identifier (e.g. `"enabled"`,
  `"redesigned"`). ``FileSwitcher`` resolves it through a
  ``ConstantSwitcher``.
- **`randomized`** — a probability distribution mapping state
  identifiers to weights between 0 and 1. ``FileSwitcher`` resolves
  it through a ``RandomSwitcher``.

> Important: The string values you return **must** match the
> ``FeatureState/identifier`` of valid cases for the corresponding
> feature. ``FileSwitcher`` will trigger an assertion failure if a
> returned identifier does not match any known state.

## Handling Filters

Filters let a single configuration file contain branches for different
contexts (e.g. `Debug` vs `Release`). When `filters` is non-empty your
parser should select the branch that matches, discarding the others.

> Note: The same filters are also forwarded to the
> ``FileSwitcherLoader``, so a loader can choose *which* data to fetch
> based on the active filters. Your parser may therefore receive data
> that is already scoped to a specific filter.

If your format does not support branching, you can safely ignore
`filters` and `categories`.

When you do support them, keep these rules in mind:

- **Consume matched filters.** When recursing into a filtered branch,
  remove the matched filter from the set so it is not matched again.
- **Validate unknown keys.** If `categories` is provided, any key that
  is neither a feature identifier nor an active filter should belong to
  one of the declared categories. Otherwise throw
  ``FileSwitcherParserError/unexpectedKeyPath(path:)``.

## Error Handling

The protocol defines two standard errors via
``FileSwitcherParserError``:

- ``FileSwitcherParserError/invalidData`` — the raw bytes could not be
  deserialized (e.g. malformed JSON).
- ``FileSwitcherParserError/unexpectedKeyPath(path:)`` — an
  unrecognized key was found at the given path.

You may throw these or define your own error types.

## Example: JSON Parser

The following example parses a flat JSON object where keys are feature
identifiers and values are either a state string or a distribution
object:

```json
{
    "DarkMode": "enabled",
    "OnboardingFlow": {
        "classic": 0.5,
        "redesigned": 0.3,
        "experimental": 0.2
    }
}
```

```swift
import Foundation

struct JSONFileSwitcherParser: FileSwitcherParser {
    func extractStateDescription(
        from data: Data,
        for features: [any Feature.Type],
        filters: Set<String>,
        categories: [FileSwitcher.Options.Category]?
    ) throws -> [String: FeatureStateDescription] {
        guard let root = try? JSONSerialization.jsonObject(
            with: data
        ) as? [String: Any] else {
            throw FileSwitcherParserError.invalidData
        }

        var descriptions: [String: FeatureStateDescription] = [:]

        for feature in features {
            guard let value = root[feature.identifier] else {
                continue
            }

            if let stateIdentifier = value as? String {
                descriptions[feature.identifier] = .constant(
                    stateIdentifier
                )
            } else if let distribution = value as? [String: Double] {
                descriptions[feature.identifier] = .randomized(
                    distribution
                )
            }
        }

        return descriptions
    }
}
```

## Plugging It In

Pass your parser to ``FileSwitcher/init(loader:parser:options:)``
alongside any ``FileSwitcherLoader``:

```swift
let switcher = FileSwitcher(
    loader: LocalFileSwitcherLoader(path: jsonFileURL),
    parser: JSONFileSwitcherParser()
)
```

You can also create a convenience factory, mirroring
``FileSwitcher/propertyList(path:options:)``:

```swift
extension FileSwitcher {
    static func json(
        path: URL,
        options: Options = .default
    ) -> FileSwitcher {
        FileSwitcher(
            loader: LocalFileSwitcherLoader(path: path),
            parser: JSONFileSwitcherParser(),
            options: options
        )
    }
}
```
