/// Which discovered types an enumeration admits.
///
/// Discovery sees every record in every loaded image. That is usually what an app wants.
/// Restrict it when several independent modules share a binary, which is what happens when
/// SwiftPM links all test targets into one bundle:
///
///     Discoverable.types(for: Plugins.self, in: .thisModule())
///     Discoverable.types(for: Plugins.self, in: .modules(["Orders", "Billing"]))
public struct DiscoveryScope: Sendable {
    let include: @Sendable (Any.Type) -> Bool

    public init(_ include: @escaping @Sendable (Any.Type) -> Bool) {
        self.include = include
    }

    /// Every record in every loaded image. The default.
    public static let all = DiscoveryScope { _ in true }

    /// Nothing.
    public static let none = DiscoveryScope { _ in false }

    /// Only types declared in the named modules.
    public static func modules(_ names: Set<String>) -> DiscoveryScope {
        DiscoveryScope { names.contains(moduleName(of: $0)) }
    }

    /// Only types declared in the same module as `type`.
    public static func module(of type: Any.Type) -> DiscoveryScope {
        .modules([moduleName(of: type)])
    }

    /// Only types declared in the module this call is written in.
    public static func thisModule(fileID: String = #fileID) -> DiscoveryScope {
        .modules([String(fileID.prefix { $0 != "/" })])
    }

    /// The module a type was declared in, from its qualified name.
    public static func moduleName(of type: Any.Type) -> String {
        String(String(reflecting: type).prefix { $0 != "." })
    }

    /// Whether the scope admits `type`.
    public func callAsFunction(_ type: Any.Type) -> Bool { include(type) }
}
