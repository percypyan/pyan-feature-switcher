# Implementing a FeatureSwitcher

Create a custom switching strategy by conforming to ``FeatureSwitcher``.

## Overview

The built-in switchers cover common scenarios — hard-coded values,
random assignment, file-driven configuration, and composition via
``MultiplexSwitcher`` — but you may need to resolve feature states
from a remote service, a database, or any other source. This guide
shows how to implement your own ``FeatureSwitcher``.

## The Protocol

``FeatureSwitcher`` has two requirements:

```swift
public protocol FeatureSwitcher {
    func generateState(
        for features: [any Feature.Type]
    ) async throws -> [String: any FeatureState]

    var logMetadata: Logger.Metadata { get }
}
```

Only ``FeatureSwitcher/generateState(for:)`` must be implemented —
``FeatureSwitcher/logMetadata`` defaults to an empty dictionary.

Your implementation receives the full list of registered ``Feature``
types and must return a dictionary that maps each feature's
``Feature/identifier`` to a resolved ``FeatureState`` value.

### Key rules

- **Return only known identifiers.** Use `Feature.identifier` as the
  dictionary key — never invent your own.
- **Match the feature's state type.** Each value must be a case of
  the feature's associated `State` enum. Use `Feature.stateType` and
  its `allCases` to look up valid values.
- **Omitting a feature is allowed.** If you don't return a key for a
  given feature, ``FeaturesManager/state(of:)`` will return a
  value default for it.

## Example: Remote Configuration Switcher

The following example fetches feature states from a JSON endpoint:

```swift
struct RemoteSwitcher: FeatureSwitcher {
    let url: URL
    let session: URLSession

    init(url: URL, session: URLSession = .shared) {
        self.url = url
        self.session = session
    }

    func generateState(
        for features: [any Feature.Type]
    ) async throws -> [String: any FeatureState] {
        let (data, _) = try await session.data(from: url)
        let payload = try JSONDecoder().decode(
            [String: String].self, from: data
        )

        var states: [String: any FeatureState] = [:]
        for feature in features {
            guard let raw = payload[feature.identifier] else { continue }
            guard let state = feature.stateType.allCases.first(where: {
                ($0 as? any FeatureState)?.identifier == raw
            }) as? any FeatureState else { continue }
            states[feature.identifier] = state
        }
        return states
    }
}
```

Then use it like any other switcher:

```swift
let manager = FeaturesManager(
    switcher: RemoteSwitcher(url: configURL)
)
.register(DarkMode.self)
.register(OnboardingFlow.self)

try await manager.bootstrap()
```

## Resolving States from Feature Metadata

The `features` array gives you access to two key pieces of metadata
for each registered feature:

| Property | Type | Description |
|---|---|---|
| `identifier` | `String` | The lookup key |
| `stateType` | `FeatureState.Type` | The associated state enum's metatype |

Use `stateType.allCases` to enumerate valid states and match them
against your data source.

## Adding Logging Metadata

``FeatureSwitcher`` exposes a ``FeatureSwitcher/logMetadata``
property that ``FeaturesManager`` includes in its own
``FeaturesManager/logMetadata``. Override it to surface
configuration details useful for diagnostics:

```swift
struct RemoteSwitcher: FeatureSwitcher {
    let url: URL
    // ...

    var logMetadata: Logger.Metadata {
        ["url": .string(url.absoluteString)]
    }
}
```
The default implementation returns an empty dictionary, so
conforming types only need to provide this when they have
meaningful configuration to expose.

