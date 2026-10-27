import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxMacros

/// Builds discovery records for peer macros.
///
/// `@Discoverable` uses this directly. A framework macro that wants its own spelling
/// (SwiftMediator's `@Handler`, say) calls the same two functions from its peer expansion:
///
///     let placement = try DiscoveryRecordSyntax.placement(of: node, on: declaration, in: context)
///     return DiscoveryRecordSyntax.declarations(recording: placement, under: "MyFramework.Handlers")
///
/// The emitted declaration spells out the record's tuple type and erases metadata with
/// `unsafeBitCast`, so the adopting module needs no import beyond the key's.
public enum DiscoveryRecordSyntax {

    /// Where a record may be placed for a declaration, and under what name.
    public struct Placement: Sendable {
        /// The nominal type's declared name.
        public let typeName: String
        /// `private` at file scope, `private static` when nested in a type.
        public let storage: String
    }

    /// Validates that `declaration` can carry a record and decides its storage.
    ///
    /// Throws a `DiagnosticsError` for non-nominal declarations, local types, and types nested
    /// in generic types. Static stored properties are not allowed in generic types or local
    /// scopes, and the record is a static stored property when nested.
    public static func placement(
        of node: AttributeSyntax,
        on declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> Placement {
        let attribute = node.attributeName.trimmed.description
        guard let name = nominalName(of: declaration) else {
            throw DiagnosticsError(diagnostics: [
                Diagnostic(node: Syntax(node), message: Message.notNominal(attribute: attribute))
            ])
        }

        var isNested = false
        for enclosing in context.lexicalContext {
            if enclosing.is(FunctionDeclSyntax.self) || enclosing.is(ClosureExprSyntax.self)
                || enclosing.is(InitializerDeclSyntax.self) || enclosing.is(AccessorDeclSyntax.self) {
                throw DiagnosticsError(diagnostics: [
                    Diagnostic(node: Syntax(node), message: Message.localType(attribute: attribute))
                ])
            }
            if hasGenericParameters(enclosing) {
                throw DiagnosticsError(diagnostics: [
                    Diagnostic(node: Syntax(node), message: Message.genericEnclosingType(attribute: attribute))
                ])
            }
            if enclosing.is(StructDeclSyntax.self) || enclosing.is(ClassDeclSyntax.self)
                || enclosing.is(ActorDeclSyntax.self) || enclosing.is(EnumDeclSyntax.self)
                || enclosing.is(ExtensionDeclSyntax.self) {
                isNested = true
            }
        }
        return Placement(typeName: name, storage: isNested ? "private static" : "private")
    }

    /// The declarations that record `placement.typeName` under each key in `keys`.
    ///
    /// One global is emitted per type, named `identifierPrefix + typeName`, so the calling
    /// macro declares `names: prefixed(<identifierPrefix>)`. Several keys become a tuple of
    /// records in that one global, which the section reader sees as consecutive records.
    ///
    /// - Parameters:
    ///   - keys: Type expressions for the keys, without `.self`, as they should appear in the
    ///     adopting module. Qualify them with their module (`"SwiftMediator.MediatorComponents"`)
    ///     unless the adopter is guaranteed to import the key's module unqualified.
    ///   - identifierPrefix: Must match the macro's `names: prefixed(...)` clause. A framework
    ///     macro should use its own prefix so a type can carry both its record and a
    ///     `@Discoverable` record.
    public static func declarations(
        recording placement: Placement,
        under keys: [String],
        identifierPrefix: String = "__discovery_record_"
    ) -> [DeclSyntax] {
        precondition(!keys.isEmpty, "at least one key")
        let identifier = "\(identifierPrefix)\(placement.typeName)"
        let recordType = "(version: UInt32, flags: UInt32, type: @convention(c) () -> UnsafeRawPointer, key: @convention(c) () -> UnsafeRawPointer)"
        func value(_ key: String, indent: String) -> String {
            """
            \(indent)version: 1,
            \(indent)flags: 0,
            \(indent)type: { unsafe unsafeBitCast(\(placement.typeName).self as Any.Type, to: UnsafeRawPointer.self) },
            \(indent)key: { unsafe unsafeBitCast(\(key).self as Any.Type, to: UnsafeRawPointer.self) }
            """
        }
        let record: String
        if keys.count == 1 {
            record = """
            let \(identifier): \(recordType) = (
            \(value(keys[0], indent: "    "))
            )
            """
        } else {
            let types = Array(repeating: recordType, count: keys.count).joined(separator: ", ")
            let values = keys.map { "    (\n\(value($0, indent: "        "))\n    )" }.joined(separator: ",\n")
            record = """
            let \(identifier): (\(types)) = (
            \(values)
            )
            """
        }
        return [
            """
            #if canImport(Darwin)
            @section("__DATA_CONST,__swift5_discov") @used
            \(raw: placement.storage) \(raw: record)
            #elseif os(Linux) || os(Android) || os(FreeBSD)
            @section("swift5_discov") @used
            \(raw: placement.storage) \(raw: record)
            #elseif os(Windows)
            @section(".discov$B") @used
            \(raw: placement.storage) \(raw: record)
            #endif
            """
        ]
    }

    // MARK: Helpers

    static func nominalName(of declaration: some DeclSyntaxProtocol) -> String? {
        if let d = declaration.as(StructDeclSyntax.self) { return d.name.trimmed.text }
        if let d = declaration.as(ClassDeclSyntax.self) { return d.name.trimmed.text }
        if let d = declaration.as(ActorDeclSyntax.self) { return d.name.trimmed.text }
        if let d = declaration.as(EnumDeclSyntax.self) { return d.name.trimmed.text }
        return nil
    }

    static func hasGenericParameters(_ node: Syntax) -> Bool {
        if let d = node.as(StructDeclSyntax.self) { return d.genericParameterClause != nil }
        if let d = node.as(ClassDeclSyntax.self) { return d.genericParameterClause != nil }
        if let d = node.as(ActorDeclSyntax.self) { return d.genericParameterClause != nil }
        if let d = node.as(EnumDeclSyntax.self) { return d.genericParameterClause != nil }
        return false
    }

    enum Message: DiagnosticMessage {
        case notNominal(attribute: String)
        case localType(attribute: String)
        case genericEnclosingType(attribute: String)

        var message: String {
            switch self {
            case .notNominal(let attribute):
                "@\(attribute) can only be applied to a struct, class, actor or enum"
            case .localType(let attribute):
                "@\(attribute) cannot be applied to a type declared inside a function; move it to type or file scope"
            case .genericEnclosingType(let attribute):
                "@\(attribute) cannot be applied to a type nested in a generic type, because the discovery record is a static stored property"
            }
        }
        var diagnosticID: MessageID { MessageID(domain: "SwiftDiscovery", id: "\(self)") }
        var severity: DiagnosticSeverity { .error }
    }
}
