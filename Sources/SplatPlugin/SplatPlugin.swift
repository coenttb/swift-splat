import SwiftCompilerPlugin
import SwiftSyntaxMacros

@main
struct SplatPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        SplatMacro.self
    ]
}
