import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest
import SwiftDiscoveryMacros

final class DiscoverableMacroTests: XCTestCase {
    let macros: [String: Macro.Type] = ["Discoverable": DiscoverableMacro.self]

    static let recordType = "(version: UInt32, flags: UInt32, type: @convention(c) () -> UnsafeRawPointer, key: @convention(c) () -> UnsafeRawPointer)"

    func testFileScopeRecord() {
        assertMacroExpansion(
            """
            @Discoverable(Plugins.self)
            struct SpellChecker: Plugin {}
            """,
            expandedSource: """
            struct SpellChecker: Plugin {}

            #if canImport(Darwin)
            @section("__DATA_CONST,__swift5_discov") @used
            private let __discovery_record_SpellChecker: \(Self.recordType) = (
                version: 1,
                flags: 0,
                type: {
                    unsafe unsafeBitCast(SpellChecker.self as Any.Type, to: UnsafeRawPointer.self)
                },
                key: {
                    unsafe unsafeBitCast(Plugins.self as Any.Type, to: UnsafeRawPointer.self)
                }
            )
            #elseif os(Linux) || os(Android) || os(FreeBSD)
            @section("swift5_discov") @used
            private let __discovery_record_SpellChecker: \(Self.recordType) = (
                version: 1,
                flags: 0,
                type: {
                    unsafe unsafeBitCast(SpellChecker.self as Any.Type, to: UnsafeRawPointer.self)
                },
                key: {
                    unsafe unsafeBitCast(Plugins.self as Any.Type, to: UnsafeRawPointer.self)
                }
            )
            #endif
            """,
            macros: macros
        )
    }

    func testSeveralKeysBecomeOneTupleOfRecords() {
        assertMacroExpansion(
            """
            @Discoverable(Plugins.self, Web.Routes.self)
            enum E {}
            """,
            expandedSource: """
            enum E {}

            #if canImport(Darwin)
            @section("__DATA_CONST,__swift5_discov") @used
            private let __discovery_record_E: (\(Self.recordType), \(Self.recordType)) = (
                (
                    version: 1,
                    flags: 0,
                    type: {
                        unsafe unsafeBitCast(E.self as Any.Type, to: UnsafeRawPointer.self)
                    },
                    key: {
                        unsafe unsafeBitCast(Plugins.self as Any.Type, to: UnsafeRawPointer.self)
                    }
                ),
                (
                    version: 1,
                    flags: 0,
                    type: {
                        unsafe unsafeBitCast(E.self as Any.Type, to: UnsafeRawPointer.self)
                    },
                    key: {
                        unsafe unsafeBitCast(Web.Routes.self as Any.Type, to: UnsafeRawPointer.self)
                    }
                )
            )
            #elseif os(Linux) || os(Android) || os(FreeBSD)
            @section("swift5_discov") @used
            private let __discovery_record_E: (\(Self.recordType), \(Self.recordType)) = (
                (
                    version: 1,
                    flags: 0,
                    type: {
                        unsafe unsafeBitCast(E.self as Any.Type, to: UnsafeRawPointer.self)
                    },
                    key: {
                        unsafe unsafeBitCast(Plugins.self as Any.Type, to: UnsafeRawPointer.self)
                    }
                ),
                (
                    version: 1,
                    flags: 0,
                    type: {
                        unsafe unsafeBitCast(E.self as Any.Type, to: UnsafeRawPointer.self)
                    },
                    key: {
                        unsafe unsafeBitCast(Web.Routes.self as Any.Type, to: UnsafeRawPointer.self)
                    }
                )
            )
            #endif
            """,
            macros: macros
        )
    }

    func testNestedTypeGetsStaticRecord() {
        assertMacroExpansion(
            """
            enum Outer {
                @Discoverable(Plugins.self)
                struct Inner {}
            }
            """,
            expandedSource: """
            enum Outer {
                struct Inner {}

                #if canImport(Darwin)
                @section("__DATA_CONST,__swift5_discov") @used
                private static let __discovery_record_Inner: \(Self.recordType) = (
                    version: 1,
                    flags: 0,
                    type: {
                        unsafe unsafeBitCast(Inner.self as Any.Type, to: UnsafeRawPointer.self)
                    },
                    key: {
                        unsafe unsafeBitCast(Plugins.self as Any.Type, to: UnsafeRawPointer.self)
                    }
                )
                #elseif os(Linux) || os(Android) || os(FreeBSD)
                @section("swift5_discov") @used
                private static let __discovery_record_Inner: \(Self.recordType) = (
                    version: 1,
                    flags: 0,
                    type: {
                        unsafe unsafeBitCast(Inner.self as Any.Type, to: UnsafeRawPointer.self)
                    },
                    key: {
                        unsafe unsafeBitCast(Plugins.self as Any.Type, to: UnsafeRawPointer.self)
                    }
                )
                #endif
            }
            """,
            macros: macros
        )
    }

    func testRejectsMissingKey() {
        assertMacroExpansion(
            """
            @Discoverable
            struct S {}
            """,
            expandedSource: """
            struct S {}
            """,
            diagnostics: [
                DiagnosticSpec(message: "@Discoverable requires at least one key, for example @Discoverable(Plugins.self)", line: 1, column: 1)
            ],
            macros: macros
        )
    }

    func testRejectsNonNominal() {
        assertMacroExpansion(
            """
            @Discoverable(Plugins.self)
            func f() {}
            """,
            expandedSource: """
            func f() {}
            """,
            diagnostics: [
                DiagnosticSpec(message: "@Discoverable can only be applied to a struct, class, actor or enum", line: 1, column: 1)
            ],
            macros: macros
        )
    }

    func testRejectsLocalType() {
        assertMacroExpansion(
            """
            func f() {
                @Discoverable(Plugins.self)
                struct S {}
            }
            """,
            expandedSource: """
            func f() {
                struct S {}
            }
            """,
            diagnostics: [
                DiagnosticSpec(message: "@Discoverable cannot be applied to a type declared inside a function; move it to type or file scope", line: 2, column: 5)
            ],
            macros: macros
        )
    }

    func testRejectsGenericEnclosingType() {
        assertMacroExpansion(
            """
            struct Box<T> {
                @Discoverable(Plugins.self)
                struct S {}
            }
            """,
            expandedSource: """
            struct Box<T> {
                struct S {}
            }
            """,
            diagnostics: [
                DiagnosticSpec(message: "@Discoverable cannot be applied to a type nested in a generic type, because the discovery record is a static stored property", line: 2, column: 5)
            ],
            macros: macros
        )
    }
}
