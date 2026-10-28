import SwiftSections

#if !compiler(>=6.3)
#error("swift-discovery requires Swift 6.3 or later: its records use @section and @used (SE-0492).")
#endif

/// Layout of one entry in the discovery section. Written by ``Discoverable(_:)`` (or a
/// framework macro built on `SwiftDiscoveryMacroSupport`), read by ``Discoverable``.
///
/// Only constant expressions may initialise a `@section` global, so the record is a plain
/// tuple of integers and non-capturing C function pointers. Each accessor returns a type's
/// metadata erased to a raw pointer; reading it back is `unsafeBitCast(ptr, to: Any.Type.self)`.
///
/// Macro expansions spell this type out in full so that adopting modules need not import
/// `SwiftDiscovery`.
public typealias DiscoveryAccessor = @convention(c) () -> UnsafeRawPointer
public typealias DiscoveryRecord = (
    version: UInt32,
    flags: UInt32,
    type: DiscoveryAccessor,
    key: DiscoveryAccessor
)

/// Section names. Mach-O section names are limited to 16 bytes.
public enum DiscoverySectionName {
    public static let machO = "__DATA_CONST,__swift5_discov"
    public static let elf = "swift5_discov"
    /// Records go in the `$B` group of the image section `.discov`; PE limits image section
    /// names to 8 bytes.
    public static let windows = ".discov$B"

    /// The name for the current object format, as read by `SectionContents`.
    #if canImport(Darwin)
    public static let current = SectionName("__DATA_CONST,__swift5_discov")
    #elseif os(Windows)
    public static let current = SectionName(".discov$B")
    #else
    public static let current = SectionName("swift5_discov")
    #endif
}

/// The record `version` the current reader understands.
public enum DiscoveryRecordVersion {
    public static let current: UInt32 = 1
}
