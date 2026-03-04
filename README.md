# PyanFeatureSwitcher

A lightweight, type-safe feature flag management system for Swift.

## Requirements

### Platform

- iOS 18.0+
- macOS 15.0+
- tvOS 18.0+
- watchOS 11.0+
- visionOS 2.0+
- Linux
- Windows

> Notice: `UserDefaultsSwitcherCache` will be unavailable on Linux and Windows.

### Toolchain

- Swift 6.2+

## Installation

Add the package dependency in your `Package.swift`:

```swift
.package(url: "https://github.com/percypyan/PyanFeatureSwitcher", from: "0.1.0")
```

## Quick Start

### Define a feature

```swift
import PyanFeatureSwitcher

enum DarkMode: Feature {}
```

### Resolve and query state

```swift
let switcher = ConstantSwitcher()
    .constant(DarkMode.self, enabled: true)

let manager = FeaturesManager(switcher: switcher)
    .register(DarkMode.self)

try await manager.bootstrap()

if manager.isEnabled(DarkMode.self) {
    // Dark mode is on
}
```

### Multi-variant features

```swift
enum OnboardingFlow: Feature {
    enum State: String, FeatureState {
        case classic, redesigned, experimental
        static let `default`: Self = .classic
    }
}

let state = manager.state(of: OnboardingFlow.self)
```

## Switchers

| Switcher | Description |
|---|---|
| `ConstantSwitcher` | Hard-coded, predetermined states |
| `RandomSwitcher` | Probability-based random assignment with persistence |
| `FileSwitcher` | Reads states from configuration files (e.g. property lists) |

Switchers can be composed using `multiplex(_:)` — later switchers take precedence.

## Caching

| Cache | Description |
|---|---|
| `InMemorySwitcherCache` | Process-lifetime storage |
| `UserDefaultsSwitcherCache` | Persists across launches (Apple platforms) |

## Documentation

See the DocC catalog included in the package for detailed guides:

- [Getting Started](Sources/PyanFeatureSwitcher/PyanFeatureSwitcher.docc/GettingStarted.md)
- [Implementing a custom `FeatureSwitcher`](Sources/PyanFeatureSwitcher/PyanFeatureSwitcher.docc/ImplementingAFeatureSwitcher.md)
- [Implementing a custom `FileSwitcherLoader`](Sources/PyanFeatureSwitcher/PyanFeatureSwitcher.docc/ImplementingAFileSwitcherLoader.md)
- [Implementing a custom `FileSwitcherParser`](Sources/PyanFeatureSwitcher/PyanFeatureSwitcher.docc/ImplementingAFileSwitcherParser.md)
- [Implementing a custom `SwitcherCache`](Sources/PyanFeatureSwitcher/PyanFeatureSwitcher.docc/ImplementingASwitcherCache.md)

## AI disclaimer

The code of this package is **entirely human-written**.
However, AI has been used to _generate unit tests suites and documentation_. Every generated bit of code or
documentation has been **reviewed and approved by a human developer**.

## License

See [LICENSE.md](LICENSE.md).
