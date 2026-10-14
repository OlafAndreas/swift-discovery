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

/// Enumerates types marked ``Discoverable(_:)``.
public enum Discoverable {
    /// Every loaded type recorded under `key`, in a stable order (sorted by qualified name)
    /// with duplicates removed.
    public static func types(for key: any DiscoveryKey.Type) -> [Any.Type] {
        cached[ObjectIdentifier(key)] ?? []
    }

    /// As ``types(for:)``, restricted to `scope`.
    public static func types(for key: any DiscoveryKey.Type, in scope: DiscoveryScope) -> [Any.Type] {
        types(for: key).filter { scope($0) }
    }

    /// Re-walks the loaded images and returns the fresh index. Only needed if an image was
    /// loaded after first use; the cached index is not replaced.
    @discardableResult
    public static func rescan() -> [ObjectIdentifier: [Any.Type]] {
        var byKey: [ObjectIdentifier: [Any.Type]] = [:]
        var seen: Set<RecordIdentity> = []
        forEachRecord { record in
            guard record.version == DiscoveryRecordVersion.current else { return }
            let type = unsafeBitCast(record.type(), to: Any.Type.self)
            let key = unsafeBitCast(record.key(), to: Any.Type.self)
            // A module linked into two images yields the same record twice.
            guard seen.insert(RecordIdentity(type: ObjectIdentifier(type), key: ObjectIdentifier(key))).inserted else { return }
            byKey[ObjectIdentifier(key), default: []].append(type)
        }
        for (key, types) in byKey {
            byKey[key] = types.sorted { String(reflecting: $0) < String(reflecting: $1) }
        }
        return byKey
    }

    /// Scanned once on first use. Swift's lazy statics are thread-safe, so concurrent callers
    /// share one scan.
    private static let cached: [ObjectIdentifier: [Any.Type]] = rescan()

    /// Called from macro-generated accessors. Erases a metatype to a raw pointer.
    @inlinable
    public static func __erase(_ type: Any.Type) -> UnsafeRawPointer {
        unsafeBitCast(type, to: UnsafeRawPointer.self)
    }

    static func forEachRecord(_ body: (DiscoveryRecord) -> Void) {
        for buffer in customSectionContents(named: DiscoverySectionName.current) {
            for record in buffer.bindMemory(to: DiscoveryRecord.self) { body(record) }
        }
    }
}

private struct RecordIdentity: Hashable {
    let type: ObjectIdentifier
    let key: ObjectIdentifier
}
