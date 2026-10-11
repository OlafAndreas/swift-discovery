import SwiftCompilerPlugin
import SwiftSyntaxMacros

@main
struct SwiftDiscoveryMacrosPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        DiscoverableMacro.self,
    ]
}
