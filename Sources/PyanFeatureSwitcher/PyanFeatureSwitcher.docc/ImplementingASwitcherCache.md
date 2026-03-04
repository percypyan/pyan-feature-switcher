# Implementing a SwitcherCache

Persist resolved feature states with a custom storage backend by conforming to ``SwitcherCache``.

## Overview

Switchers like ``RandomSwitcher`` and ``FileSwitcher`` rely on a
``SwitcherCache`` to keep a feature's resolved state stable across
launches. The library ships with two built-in implementations:

- ``InMemorySwitcherCache`` — process-scoped, useful for tests
- ``UserDefaultsSwitcherCache`` — persists across launches (Apple platforms)

If you need to store states in a different backend — Keychain, a
database, CloudKit, or a custom file — implement your own cache.

## The Protocol

``SwitcherCache`` has two requirements:

```swift
public protocol SwitcherCache {
    func persist(_ value: any FeatureState, key type: any Feature.Type, with filters: Set<String>)
    func load(for type: any Feature.Type, with filters: Set<String>) -> (any FeatureState)?
}
```

Both methods receive the feature's metatype and a set of **filter**
strings that describe the current context.

### Convenience Overloads

A default extension provides filter-free overloads that forward an
empty set:

```swift
cache.persist(state, key: DarkMode.self)      // filters: []
cache.load(for: DarkMode.self)                // filters: []
```

Use the filter-free variants when your switcher does not use filters.

## Handling Filters

Filters allow the same feature to have **different cached values**
depending on the active context. For example, a ``FileSwitcher``
configured with `"Debug"` filters will persist and load states under a
key that includes `"Debug"`, keeping them separate from `"Release"`
states.

When building your cache key, incorporate the filters so that
different filter sets never collide:

```swift
private func key(for type: any Feature.Type, with filters: Set<String>) -> String {
    let filterPrefix = filters.isEmpty ? "" : "\(filters.sorted().joined(separator: "."))."
    return "\(filterPrefix)\(type)"
}
```

> Important: `Set` is unordered. Always sort the filters before
> building the key to ensure deterministic lookups.

## Resolving States from Feature Metadata

The `type` parameter gives you access to two key pieces of metadata:

| Property | Type | Description |
|---|---|---|
| `identifier` | `String` | A stable lookup key for the feature |
| `stateType` | `FeatureState.Type` | The associated state enum's metatype |

When loading a value, use `stateType.allCases` to find the case whose
``FeatureState/identifier`` matches the stored string.

## Plugging It In

Pass your cache to any switcher that accepts one:

```swift
let cache = KeychainSwitcherCache()

let randomSwitcher = RandomSwitcher(cache: cache)

let fileSwitcher = FileSwitcher.propertyList(
    path: fileURL,
    options: try .init(filters: ["Release"], cache: cache)
)
```
