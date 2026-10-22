/// A marker type that names a discovery set.
///
/// Keys are usually caseless enums owned by the framework that enumerates them:
///
///     public enum Plugins: DiscoveryKey {}
///
///     @Discoverable(Plugins.self)
///     struct SpellChecker: Plugin { ... }
///
///     for type in Discoverable.types(for: Plugins.self) { ... }
///
/// A key carries no requirements. A framework that needs conformance checks it after
/// enumeration with `as?`.
public protocol DiscoveryKey {}
