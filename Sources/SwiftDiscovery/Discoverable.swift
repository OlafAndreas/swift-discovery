@_exported import SwiftDiscoveryCore

/// Marks a nominal type for discovery under one or more keys.
///
/// Expands to a constant record per key in a dedicated binary section. Nothing runs at load
/// time; ``Discoverable/types(for:)`` reads the section back.
///
///     @Discoverable(Plugins.self)
///     struct SpellChecker: Plugin {}
///
///     @Discoverable(Plugins.self, Routes.self)   // listed under both
///     struct HealthRoute {}
///
/// Apply it once per type; list several keys in that one application. The attribute is
/// rejected on local types and on types nested in generic types, because the record is a
/// stored global or static property.
@attached(peer, names: prefixed(__discovery_record_))
public macro Discoverable(_ keys: any DiscoveryKey.Type...) =
    #externalMacro(module: "SwiftDiscoveryMacros", type: "DiscoverableMacro")
