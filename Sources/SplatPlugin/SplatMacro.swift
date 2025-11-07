import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

public struct SplatMacro: MemberMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {

        // Extract macro arguments
        let structName: String
        let propertyName: String

        if case .argumentList(let arguments) = node.arguments {
            // Parse structName if provided
            if let structArg = arguments.first(where: { $0.label?.text == "structName" }),
                let stringLiteral = structArg.expression.as(StringLiteralExprSyntax.self),
                stringLiteral.segments.count == 1,
                case .stringSegment(let segment) = stringLiteral.segments.first
            {
                structName = segment.content.text
            } else {
                structName = "Arguments"
            }

            // Parse propertyName if provided
            if let propArg = arguments.first(where: { $0.label?.text == "propertyName" }),
                let stringLiteral = propArg.expression.as(StringLiteralExprSyntax.self),
                stringLiteral.segments.count == 1,
                case .stringSegment(let segment) = stringLiteral.segments.first
            {
                propertyName = segment.content.text
            } else {
                propertyName = "arguments"
            }
        } else {
            structName = "Arguments"
            propertyName = "arguments"
        }

        // Find the target struct
        guard
            let targetStruct = declaration.memberBlock.members
                .compactMap({ $0.decl.as(StructDeclSyntax.self) })
                .first(where: { $0.name.text == structName })
        else {
            throw SplatError.noTargetStruct(structName)
        }

        // Helper to strip backticks from identifier text
        func stripBackticks(_ text: String) -> String {
            if text.hasPrefix("`") && text.hasSuffix("`") && text.count > 2 {
                return String(text.dropFirst().dropLast())
            }
            return text
        }

        // Extract properties from target struct
        let properties = targetStruct.memberBlock.members
            .compactMap { $0.decl.as(VariableDeclSyntax.self) }
            .filter { $0.bindings.first?.accessorBlock == nil }  // Only stored properties
            .flatMap { variable -> [(String, TypeSyntax)] in
                variable.bindings.compactMap { binding in
                    guard let identifier = binding.pattern.as(IdentifierPatternSyntax.self),
                        let type = binding.typeAnnotation?.type
                    else {
                        return nil
                    }
                    // Strip backticks from identifier text to avoid double-backticking
                    let name = stripBackticks(identifier.identifier.text)
                    return (name, type)
                }
            }

        guard !properties.isEmpty else {
            throw SplatError.noProperties
        }

        // Find if there's a throwing initializer
        let hasThrowingInit = declaration.memberBlock.members
            .compactMap { $0.decl.as(InitializerDeclSyntax.self) }
            .contains { initializer in
                initializer.signature.effectSpecifiers?.throwsClause != nil
            }

        // Build parameter list
        let parameters = properties.map { name, type in
            FunctionParameterSyntax(
                firstName: .identifier("`\(name)`"),
                type: type
            )
        }

        // Build target struct initializer call arguments
        let argumentsCallArgs = properties.map { name, _ in
            LabeledExprSyntax(
                label: .identifier("`\(name)`"),
                colon: .colonToken(trailingTrivia: .space),
                expression: DeclReferenceExprSyntax(baseName: .identifier("`\(name)`"))
            )
        }

        // Determine if we need typed throws
        let throwsClause: String
        if hasThrowingInit {
            // Check if there's a typed throws (Error type)
            if let errorType = declaration.memberBlock.members
                .compactMap({ $0.decl.as(InitializerDeclSyntax.self) })
                .first(where: { $0.signature.effectSpecifiers?.throwsClause != nil })?
                .signature.effectSpecifiers?.throwsClause?.type
            {
                throwsClause = "throws(\(errorType.trimmed))"
            } else {
                throwsClause = "throws"
            }
        } else {
            throwsClause = ""
        }

        // Build the try keyword if needed
        let tryKeyword = hasThrowingInit ? "try " : ""

        // Generate parameter documentation
        let parameterDocs = properties.map { name, type in
            "///   - \(name): \(type.trimmed)"
        }.joined(separator: "\n")

        // Generate throws documentation if needed
        let throwsDocs = hasThrowingInit ? "\n/// - Throws: Error if initialization fails." : ""

        // Generate the convenience initializer with comprehensive DocC comments
        let initializer: DeclSyntax = """
            /// Initializer accepting ``\(raw: structName)`` properties as individual parameters.
            ///
            /// This initializer provides direct parameter access without explicitly creating
            /// a ``\(raw: structName)`` instance.
            ///
            /// - Parameters:
            \(raw: parameterDocs)\(raw: throwsDocs)
            public init(
                \(raw: parameters.map { "\($0)" }.joined(separator: ",\n    "))
            ) \(raw: throwsClause) {
                \(raw: tryKeyword)self.init(\(raw: structName)(
                    \(raw: argumentsCallArgs.map { "\($0)" }.joined(separator: ",\n        "))
                ))
            }
            """

        return [initializer]
    }
}

enum SplatError: Error, CustomStringConvertible {
    case noTargetStruct(String)
    case noProperties

    var description: String {
        switch self {
        case .noTargetStruct(let name):
            return "@Splat requires a nested struct named '\(name)'"
        case .noProperties:
            return "Target struct has no stored properties to splat"
        }
    }
}
