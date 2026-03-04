# Implementing a FileSwitcherLoader

Load configuration data from any source by conforming to ``FileSwitcherLoader``.

## Overview

``FileSwitcher`` delegates data retrieval to a ``FileSwitcherLoader``.
The library ships with ``LocalFileSwitcherLoader`` for the local
filesystem, but you can load data from a remote server, a database,
an encrypted store, or any other source by implementing this protocol.

## The Protocol

``FileSwitcherLoader`` has a single requirement:

```swift
public protocol FileSwitcherLoader {
    func loadData(filters: Set<String>) async throws -> Data
}
```

The `filters` parameter contains the active filter keys configured in
``FileSwitcher/Options`` (e.g. `"Debug"`, `"Release"`). This allows
your loader to fetch data that is already scoped to the current
context, rather than returning a single monolithic payload that the
parser must then filter.

If filters are not relevant to your data source, you can ignore the
parameter.

## Example: Remote Loader

The following loader fetches configuration data from a URL, appending
the active filters as query parameters:

```swift
import Foundation

struct RemoteFileSwitcherLoader: FileSwitcherLoader {
    let baseURL: URL
    let session: URLSession

    init(baseURL: URL, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }

    func loadData(filters: Set<String>) async throws -> Data {
        var components = URLComponents(
            url: baseURL,
            resolvingAgainstBaseURL: false
        )!
        if !filters.isEmpty {
            components.queryItems = filters.sorted().map {
                URLQueryItem(name: "filter", value: $0)
            }
        }
        let (data, _) = try await session.data(from: components.url!)
        return data
    }
}
```

## Plugging It In

Pass your loader to ``FileSwitcher/init(loader:parser:options:)``
alongside any ``FileSwitcherParser``:

```swift
let switcher = FileSwitcher(
    loader: RemoteFileSwitcherLoader(baseURL: configURL),
    parser: PropertyListFileSwitcherParser()
)
```
