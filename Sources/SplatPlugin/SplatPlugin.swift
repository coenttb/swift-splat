import SwiftCompilerPlugin
import SwiftSyntaxMacros
import SplatMacros

@main
struct SplatPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        SplatMacro.self
    ]
}
