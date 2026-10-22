import Testing
import SwiftDiscovery

@Suite struct DiscoverableTests {

    private func names(_ types: [Any.Type]) -> [String] {
        types.map { String(reflecting: $0) }
    }

    @Test func findsEveryTypeMarkedWithTheKey() {
        let found = Discoverable.types(for: Plugins.self, in: .thisModule())
        let plugins = found.compactMap { $0 as? any Plugin.Type }.map { $0.name }
        #expect(Set(plugins) == ["spell", "lint", "index", "format", "health", "nested"])
        #expect(plugins.count == found.count, "everything under Plugins conforms to Plugin")
    }

    @Test func optInIsByKeyNotByConformance() {
        let found = Discoverable.types(for: Plugins.self, in: .thisModule())
        #expect(!found.contains { $0 == Unmarked.self })
    }

    @Test func aTypeCanBeListedUnderSeveralKeys() {
        let routes = Discoverable.types(for: Routes.self, in: .thisModule())
        #expect(routes.contains { $0 == HealthRoute.self })
        #expect(routes.contains { $0 == OrdersRoute.self })
        #expect(routes.contains { $0 == Outer.Deeper.TwiceNested.self })
        #expect(!routes.contains { $0 == SpellChecker.self })
    }

    @Test func unusedKeyIsEmpty() {
        #expect(Discoverable.types(for: Unused.self).isEmpty)
    }

    @Test func orderIsStableAndSortedByQualifiedName() {
        let a = names(Discoverable.types(for: Plugins.self, in: .thisModule()))
        let b = names(Discoverable.types(for: Plugins.self, in: .thisModule()))
        #expect(a == b)
        #expect(a == a.sorted())
    }

    @Test func noDuplicates() {
        let all = names(Discoverable.types(for: Plugins.self))
        #expect(Set(all).count == all.count)
    }

    @Test func rescanMatchesTheCachedIndex() {
        let fresh = Discoverable.rescan()[ObjectIdentifier(Plugins.self)] ?? []
        #expect(names(fresh) == names(Discoverable.types(for: Plugins.self)))
    }

    @Test func scopes() {
        #expect(DiscoveryScope.moduleName(of: SpellChecker.self) == "SwiftDiscoveryTests")
        #expect(DiscoveryScope.moduleName(of: Outer.Deeper.TwiceNested.self) == "SwiftDiscoveryTests")
        #expect(DiscoveryScope.moduleName(of: Discoverable.self) == "SwiftDiscoveryCore")

        #expect(Discoverable.types(for: Plugins.self, in: .none).isEmpty)
        #expect(Discoverable.types(for: Plugins.self, in: .modules(["Nope"])).isEmpty)
        #expect(Discoverable.types(for: Plugins.self, in: .module(of: SpellChecker.self)).count == 6)
        #expect(Discoverable.types(for: Plugins.self, in: .all).count >= 6)
    }
}
