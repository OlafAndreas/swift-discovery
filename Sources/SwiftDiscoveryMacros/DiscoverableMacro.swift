import SwiftDiagnostics
import SwiftDiscoveryMacroSupport
import SwiftSyntax
import SwiftSyntaxMacros

/// Implements `@Discoverable(Key.self, ...)`: emits one discovery record per key.
public struct DiscoverableMacro: PeerMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        let arguments = node.arguments?.as(LabeledExprListSyntax.self) ?? []
        let keys = arguments.compactMap { keyTypeExpression($0.expression) }
        guard !keys.isEmpty, keys.count == arguments.count else {
            throw DiagnosticsError(diagnostics: [
                Diagnostic(node: Syntax(node), message: Message.missingKey)
            ])
        }
        let placement = try DiscoveryRecordSyntax.placement(of: node, on: declaration, in: context)
        return DiscoveryRecordSyntax.declarations(recording: placement, under: keys)
    }

    /// `Plugins.self` → `"Plugins"`; `Module.Plugins.self` → `"Module.Plugins"`.
    private static func keyTypeExpression(_ expression: ExprSyntax) -> String? {
        guard let member = expression.as(MemberAccessExprSyntax.self),
              member.declName.baseName.tokenKind == .keyword(.self),
              let base = member.base
        else { return nil }
        return base.trimmed.description
    }

    enum Message: DiagnosticMessage {
        case missingKey
        var message: String { "@Discoverable requires at least one key, for example @Discoverable(Plugins.self)" }
        var diagnosticID: MessageID { MessageID(domain: "SwiftDiscovery", id: "\(self)") }
        var severity: DiagnosticSeverity { .error }
    }
}
