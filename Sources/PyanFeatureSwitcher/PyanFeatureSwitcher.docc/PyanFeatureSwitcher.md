# ``PyanFeatureSwitcher``

Type-safe and thread-safe feature flags with pluggable state resolution strategies.

## Overview

PyanFeatureSwitcher provides a lightweight, protocol-oriented system for
managing feature flags. Features are defined as types conforming to
``Feature``, and their states are resolved at runtime by a
``FeatureSwitcher`` strategy.

> Note: This library is thread-safe.

### Key Concepts

- **Features** — types conforming to ``Feature`` with an associated ``FeatureState``
- **Switchers** — strategies that decide which state a feature should be in
- **Caching** — persistence of resolved states across launches via ``SwitcherCache``
- **Manager** — ``FeatureManager`` ties everything together and exposes a query API

### Quick Example

```swift
import PyanFeatureSwitcher

// 1. Define a feature
enum DarkMode: Feature {}

// 2. Pick a switcher
let switcher = ConstantSwitcher()
    .constant(DarkMode.self, enabled: true)

// 3. Bootstrap the manager
let manager = FeatureManager(switcher: switcher)
    .register(DarkMode.self)

try await manager.bootstrap()

// 4. Query state
if manager.isEnabled(DarkMode.self) {
    // apply dark theme
}
```

For a step-by-step walkthrough see <doc:GettingStarted>.

## Topics

### Essentials

- <doc:GettingStarted>
- ``Feature``
- ``FeatureState``
- ``BooleanState``
- ``FeatureManager``

### Switchers

- <doc:ImplementingAFeatureSwitcher>
- ``FeatureSwitcher``
- ``ConstantSwitcher``
- ``RandomSwitcher``
- ``MultiplexSwitcher``

### File-Based Switching

- <doc:ImplementingAFileSwitcherLoader>
- <doc:ImplementingAFileSwitcherParser>
- ``FileSwitcher``
- ``FileSwitcher/Options``
- ``FileSwitcherLoader``
- ``LocalFileSwitcherLoader``
- ``FileSwitcherParser``
- ``PropertyListFileSwitcherParser``
- ``FeatureStateDescription``

### Caching

- <doc:ImplementingASwitcherCache>
- ``SwitcherCache``
- ``InMemorySwitcherCache``
- ``UserDefaultsSwitcherCache``

### Convenience

- ``ConstantFeatureManagerFactory``
