# Getting Started

Define features, choose a switching strategy, and query state at runtime.

## Overview

This guide walks through defining features, configuring switchers,
bootstrapping the manager, and querying feature states.

## Defining Features

A feature is a type conforming to ``Feature``. The default state type
is ``BooleanState`` (enabled / disabled):

```swift
enum DarkMode: Feature {}
```

For multi-variant features, declare a custom ``FeatureState``:

```swift
enum OnboardingFlow: Feature {
    enum State: String, FeatureState {
        case classic
        case redesigned
        case experimental
    }
}
```

If you want to reuse and existing enum, you can also use `typealias`:

```swift
enum OnboardingVariant: String, FeatureState { /* ... */ }

enum OnboardingFlow: Feature {
    typealias State = OnboardingVariant
}
```

### Default state

By default, the **first defined case** will be used as the default, but you
can explicitly define a default state for a feature.

```swift
enum OnboardingFlow: Feature {
    enum State: String, FeatureState {
        case classic // Implicitly used
		case redesigned
        case experimental

        // Explicits the default to use
        static let `default`: Self = .redesigned
    }
}
```

## Choosing a Switcher

### Constant values

Use ``ConstantSwitcher`` when states are known ahead of time:

```swift
let switcher = ConstantSwitcher()
    .constant(DarkMode.self, enabled: true)
    .constant(OnboardingFlow.self, state: .redesigned)
```

### Random assignment

Use ``RandomSwitcher`` for probability-based assignment. Once a
state is chosen it is persisted in the provided ``SwitcherCache``:

```swift
let switcher = RandomSwitcher()
    .probabilities(for: OnboardingFlow.self, [
        .classic: 0.5,
        .redesigned: 0.3,
        .experimental: 0.2
    ])
```

### File-driven configuration

Use ``FileSwitcher`` to read states from a property list (or any
custom format via ``FileSwitcherParser``):

```swift
let path = Bundle.main.url(forResource: "Features", withExtension: "plist")!
let switcher = FileSwitcher.propertyList(path: path)
```

The plist can contain constant values, randomized distributions,
and filter branches (e.g. per build configuration).

> info: Behind the hood, ``FileSwitcher`` uses ``ConstantSwitcher`` and
``RandomSwitcher`` to handle different configuration.

#### Using LocalFileSwitcherLoader

Use ``LocalFileSwitcherLoader`` to load a file from the local file system.

``LocalFileSwitcherLoader`` provides two initializers:

- **Static path** — ``LocalFileSwitcherLoader/init(path:)`` reads from
a fixed URL, ignoring filters.

```swift
let loader = LocalFileSwitcherLoader(
    path: Bundle.main.url(forResource: "Features", withExtension: "plist")!
)
}
```

- **Factory** — ``LocalFileSwitcherLoader/init(factory:)`` receives
the active filters and returns the URL to read from:

```swift
let loader = LocalFileSwitcherLoader { filters in
    Bundle.main.url(
        forResource: "Features-\(filters.sorted().joined(separator: "-"))",
        withExtension: "plist"
    )!
}
```

> Notice: Filters are passed using a `Set`, which are unordered by default. You will need
> to order them in some way to ensure you always pass the same path for a given filters
> `Set`.

#### Custom `FileSwitcherLoader` and `FileSwitcherParser`

You can implement custom ``FileSwitcherLoader`` and ``FileSwitcherParser`` (or
use third-party ones) to load states from different sources and format. For
example, you could define `RemoteFileSwitcherLoader` and
`JSONFileSwitcherParser` to handle a JSON file served over the internet.

See <doc:ImplementingAFileSwitcherLoader> and
<doc:ImplementingAFileSwitcherParser> for detailed guides.

### Combining switchers

Compose multiple switchers with ``MultiplexSwitcher`` or the
convenience ``FeatureSwitcher/multiplex(_:)`` extension.
Later switchers in the array take precedence:

```swift
let switcher = MultiplexSwitcher(switchers: [
    FileSwitcher.propertyList(path: fileURL),
    ConstantSwitcher().constant(DarkMode.self, enabled: true)
])
```

Or equivalently, using the extensions:

```swift
let switcher = ConstantSwitcher() // Has priority
    .constant(DarkMode.self, enabled: true)
	.multiplex(FileSwitcher.propertyList(path: fileURL))
```

## Bootstrapping the Manager

Every manager needs to be booststraped once and only once. This
will trigger the effective setting of a state of each registered feature
using its switcher.

Register your features, then call ``FeatureManager/bootstrap()``:

```swift
let manager = FeatureManager(switcher: switcher)
    .register(DarkMode.self)
    .register(OnboardingFlow.self)

try await manager.bootstrap()
```

## Querying State

For boolean features use the convenience ``FeatureManager/isEnabled(_:)``:

```swift
if manager.isEnabled(DarkMode.self) { ... }
```

For multi-variant features use ``FeatureManager/state(of:)``:

```swift
switch manager.state(of: OnboardingFlow.self) {
case .classic:
    showClassicOnboarding()
case .redesigned:
    showRedesignedOnboarding()
case .experimental:
    showExperimentalOnboarding()
}
```

## Caching

Switchers that involve randomness or file loading use a
``SwitcherCache`` to persist results:

- ``UserDefaultsSwitcherCache`` (default on Apple platforms) —
  persists across launches
- ``InMemorySwitcherCache`` — useful for testing or ephemeral contexts

Pass a custom cache when creating a switcher:

```swift
let switcher = RandomSwitcher(cache: InMemorySwitcherCache())
```

### Filter-Aware Caching

Cache operations accept a `filters` parameter so the same feature can
have different cached states depending on the active context
(e.g. `"Debug"` vs `"Release"`). When no filters are provided the
convenience overloads default to an empty set.

``FileSwitcher`` automatically forwards its ``FileSwitcher/Options``
filters to the cache, ensuring that switching contexts does not
silently return a stale value from a different filter branch.

See <doc:ImplementingASwitcherCache> for a guide on building a custom
cache implementation.

