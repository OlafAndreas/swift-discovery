import SwiftDiscovery

enum Plugins: DiscoveryKey {}
enum Routes: DiscoveryKey {}
enum Unused: DiscoveryKey {}

protocol Plugin { static var name: String { get } }

@Discoverable(Plugins.self)
struct SpellChecker: Plugin { static let name = "spell" }

@Discoverable(Plugins.self)
final class Linter: Plugin { static let name = "lint" }

@Discoverable(Plugins.self)
actor Indexer: Plugin { static let name = "index" }

@Discoverable(Plugins.self)
enum Formatter: Plugin { static let name = "format" }

/// Listed under two keys.
@Discoverable(Plugins.self, Routes.self)
struct HealthRoute: Plugin { static let name = "health" }

@Discoverable(Routes.self)
struct OrdersRoute {}

enum Outer {
    @Discoverable(Plugins.self)
    struct Nested: Plugin { static let name = "nested" }

    enum Deeper {
        @Discoverable(Routes.self)
        struct TwiceNested {}
    }
}

/// Conforms to `Plugin` but is not marked, so it must never be discovered.
struct Unmarked: Plugin { static let name = "unmarked" }
