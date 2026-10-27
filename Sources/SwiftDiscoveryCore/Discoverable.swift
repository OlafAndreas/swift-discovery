import SwiftSections

/// Enumerates types marked `@Discoverable`, or recorded by a framework macro.
public enum Discoverable {
    /// Every loaded type recorded under `key`, in a stable order (sorted by mangled name)
    /// with duplicates removed. The order is the same on every launch of the same binary, and
    /// is not alphabetical: sort by your own key where order matters.
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
            // Mangled names are read from the type's descriptor; a qualified name is built by
            // demangling, which costs tens of microseconds per type the first time.
            byKey[key] = types.map { (_mangledTypeName($0) ?? "", $0) }.sorted { $0.0 < $1.0 }.map(\.1)
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
        for buffer in SectionContents.loaded(DiscoverySectionName.current) {
            for record in buffer.bindMemory(to: DiscoveryRecord.self) { body(record) }
        }
    }
}

private struct RecordIdentity: Hashable {
    let type: ObjectIdentifier
    let key: ObjectIdentifier
}
