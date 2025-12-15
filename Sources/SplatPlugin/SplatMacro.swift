import Foundation
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

public struct SplatMacro: MemberMacro {
    // Helper struct to avoid large tuple warning
    private struct PropertyInfo {
        let name: String
        let type: TypeSyntax
        let doc: String?
        let path: [String]  // Path to this property (e.g., ["lid1", "condition"])

        init(name: String, type: TypeSyntax, doc: String?, path: [String] = []) {
            self.name = name
            self.type = type
            self.doc = doc
            self.path = path
        }
    }

    // swiftlint:disable:next cyclomatic_complexity
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

        // Helper to trim whitespace using only stdlib
        func trimWhitespace(_ text: String) -> String {
            var result = text
            // Trim leading whitespace
            while result.first?.isWhitespace == true {
                result.removeFirst()
            }
            // Trim trailing whitespace
            while result.last?.isWhitespace == true {
                result.removeLast()
            }
            return result
        }

        // Helper to recursively collect properties, including from nested Arguments structs
        func collectProperties(
            from targetStruct: StructDeclSyntax,
            in declaration: some DeclGroupSyntax,
            path: [String] = []
        ) -> [PropertyInfo] {
            // Check if there's an explicit init with no parameters (all defaults)
            let explicitInits = targetStruct.memberBlock.members
                .compactMap { $0.decl.as(InitializerDeclSyntax.self) }

            // If there's an explicit init with no parameters, assume all properties have defaults
            if let firstInit = explicitInits.first,
                firstInit.signature.parameterClause.parameters.isEmpty
            {
                return []
            }

            // Otherwise, collect properties (either from explicit init with params or synthesized memberwise init)

            // Extract direct properties from this struct
            let directProperties = targetStruct.memberBlock.members
                .compactMap { $0.decl.as(VariableDeclSyntax.self) }
                .filter { $0.bindings.first?.accessorBlock == nil }  // Only stored properties
                .flatMap { variable -> [PropertyInfo] in
                    let docComment = extractDocComment(from: variable)
                    return variable.bindings.compactMap { binding in
                        guard let identifier = binding.pattern.as(IdentifierPatternSyntax.self),
                            let type = binding.typeAnnotation?.type
                        else {
                            return nil
                        }
                        let name = stripBackticks(identifier.identifier.text)
                        return PropertyInfo(name: name, type: type, doc: docComment, path: path)
                    }
                }

            // Check each property to see if it's a nested Arguments type
            var allProperties: [PropertyInfo] = []

            for property in directProperties {
                // Check if this property's type is SomeType.Arguments
                let typeString = property.type.trimmed.description

                if typeString.hasSuffix(".Arguments") {
                    // Extract the parent type name (e.g., "Lid 1" from "`Lid 1`.Arguments")
                    var parentTypeName = typeString
                    if parentTypeName.hasSuffix(".Arguments") {
                        parentTypeName = String(parentTypeName.dropLast(".Arguments".count))
                    }
                    // Remove leading/trailing backticks
                    parentTypeName = parentTypeName.trimmingCharacters(
                        in: CharacterSet(charactersIn: "`")
                    )

                    // Find the struct for this nested Arguments
                    if let nestedStruct = declaration.memberBlock.members
                        .compactMap({ $0.decl.as(StructDeclSyntax.self) })
                        .first(where: { stripBackticks($0.name.text) == parentTypeName }),
                        let nestedArgumentsStruct = nestedStruct.memberBlock.members
                            .compactMap({ $0.decl.as(StructDeclSyntax.self) })
                            .first(where: { $0.name.text == "Arguments" })
                    {
                        // Recursively collect properties from the nested Arguments struct
                        let nestedPath = path + [property.name]
                        let nestedProperties = collectProperties(
                            from: nestedArgumentsStruct,
                            in: declaration,
                            path: nestedPath
                        )
                        allProperties.append(contentsOf: nestedProperties)
                    } else {
                        // Couldn't find nested struct, keep the property as-is
                        allProperties.append(property)
                    }
                } else {
                    // Not a nested Arguments type, keep as-is
                    allProperties.append(property)
                }
            }

            return allProperties
        }

        // Helper to extract doc comment from trivia
        func extractDocComment(from variable: VariableDeclSyntax) -> String? {
            let trivia = variable.leadingTrivia
            var docLines: [String] = []

            for piece in trivia {
                switch piece {
                case .docLineComment(let text):
                    // Remove "/// " prefix and trim
                    let cleaned = trimWhitespace(text.trimmingPrefix("///"))
                    // Keep empty lines to preserve DocC paragraph structure
                    docLines.append(cleaned)
                case .docBlockComment(let text):
                    // Remove "/**" and "*/" and clean up each line
                    let lines =
                        text
                        .trimmingPrefix("/**")
                        .trimmingSuffix("*/")
                        .split(separator: "\n")
                        .map { line -> String in
                            let trimmed = trimWhitespace(String(line))
                            return trimWhitespace(trimmed.trimmingPrefix("*"))
                        }
                    // Keep empty lines for DocC structure
                    docLines.append(contentsOf: lines)
                default:
                    break
                }
            }

            // Join lines with proper DocC formatting (newline + indentation)
            // This preserves DocC callouts like "- Note:", "- Important:", etc.
            return docLines.isEmpty ? nil : docLines.joined(separator: "\n///     ")
        }

        // Extract properties from target struct with their documentation
        // This recursively collects properties from nested Arguments structs
        let properties = collectProperties(from: targetStruct, in: declaration)

        // Check if the containing struct has any output properties (properties other than arguments)
        // If not, this is a "witness type" and the result can be discarded
        let allStoredProperties = declaration.memberBlock.members
            .compactMap { $0.decl.as(VariableDeclSyntax.self) }
            .filter { $0.bindings.first?.accessorBlock == nil }  // Only stored properties

        let hasOutputProperties = allStoredProperties.contains { variable in
            variable.bindings.contains { binding in
                guard let identifier = binding.pattern.as(IdentifierPatternSyntax.self) else {
                    return false
                }
                let name = stripBackticks(identifier.identifier.text)
                return name != propertyName  // Not the arguments property
            }
        }

        let discardableResultAttr = hasOutputProperties ? "" : "@discardableResult\n"

        // If no properties to splat (empty init with default values), generate simple passthrough
        guard !properties.isEmpty else {
            // Generate a simple initializer that just calls Arguments()
            let summaryDoc = """
                /// Initializer that creates a ``\(structName)`` instance with default values.
                """

            let simpleInit: DeclSyntax = """
                \(raw: discardableResultAttr)\(raw: summaryDoc)
                public init() {
                    self.init(\(raw: structName)())
                }
                """

            return [simpleInit]
        }

        // Find if there's a throwing initializer
        let hasThrowingInit = declaration.memberBlock.members
            .compactMap { $0.decl.as(InitializerDeclSyntax.self) }
            .contains { initializer in
                initializer.signature.effectSpecifiers?.throwsClause != nil
            }

        // Build parameter list
        let parameters = properties.map { property in
            FunctionParameterSyntax(
                firstName: .identifier("`\(property.name)`"),
                type: property.type
            )
        }

        // Build target struct initializer call arguments
        // Group properties by their path to construct nested Arguments structs
        func buildArgumentsInit(properties: [PropertyInfo]) -> String {
            // Check if all properties have the same empty path (direct properties)
            let allDirect = properties.allSatisfy { $0.path.isEmpty }

            if allDirect {
                // All properties are direct - just list them
                return properties.map { "`\($0.name)`: `\($0.name)`" }.joined(separator: ", ")
            }

            // Group properties by their first path component
            let grouped = Dictionary(grouping: properties) { $0.path.first }

            let args = grouped.sorted { a, b in
                // Sort by first path component (nil first, then alphabetically)
                guard let aKey = a.key else { return true }
                guard let bKey = b.key else { return false }
                return aKey < bKey
            }.map { key, props -> String in
                if let pathComponent = key {
                    // Has nested path - recursively build nested init
                    // Remove first path component from each property
                    let nestedProps = props.map { prop in
                        PropertyInfo(
                            name: prop.name,
                            type: prop.type,
                            doc: prop.doc,
                            path: Array(prop.path.dropFirst())
                        )
                    }
                    let nestedInit = buildArgumentsInit(properties: nestedProps)
                    return "`\(pathComponent)`: .init(\(nestedInit))"
                } else {
                    // No nested path - direct properties
                    return props.map { "`\($0.name)`: `\($0.name)`" }.joined(separator: ", ")
                }
            }.joined(separator: ",\n        ")

            return args
        }

        let argumentsCallArgs = buildArgumentsInit(properties: properties)

        // Determine if we need typed throws
        let throwsClause: String
        if hasThrowingInit {
            // Check if there's a typed throws (Error type)
            if let errorType = declaration.memberBlock.members
                .compactMap({ $0.decl.as(InitializerDeclSyntax.self) })
                .first(where: { $0.signature.effectSpecifiers?.throwsClause != nil })?
                .signature.effectSpecifiers?.throwsClause?.type
            {
                throwsClause = "throws(Self.\(errorType.trimmed))"
            } else {
                throwsClause = "throws"
            }
        } else {
            throwsClause = ""
        }

        // Build the try keyword if needed
        let tryKeyword = hasThrowingInit ? "try " : ""

        // Extract full documentation from Arguments initializer
        let (argumentsInitDoc, argumentsParamDocs): (String?, [String: String]) = {
            let inits = targetStruct.memberBlock.members
                .compactMap { $0.decl.as(InitializerDeclSyntax.self) }

            guard let firstInit = inits.first else { return (nil, [:]) }

            let trivia = firstInit.leadingTrivia
            var docLines: [String] = []

            for piece in trivia {
                switch piece {
                case .docLineComment(let text):
                    let cleaned = trimWhitespace(text.trimmingPrefix("///"))
                    // Keep empty lines to preserve DocC paragraph structure
                    docLines.append(cleaned)
                case .docBlockComment(let text):
                    let lines =
                        text
                        .trimmingPrefix("/**")
                        .trimmingSuffix("*/")
                        .split(separator: "\n")
                        .map { line -> String in
                            let trimmed = trimWhitespace(String(line))
                            return trimWhitespace(trimmed.trimmingPrefix("*"))
                        }
                    // Keep empty lines for DocC structure
                    docLines.append(contentsOf: lines)
                default:
                    break
                }
            }

            // Find where "- Parameters:" starts
            guard let paramIndex = docLines.firstIndex(where: { $0.hasPrefix("- Parameters:") })
            else {
                return (docLines.isEmpty ? nil : docLines.joined(separator: "\n/// "), [:])
            }

            // Extract summary/discussion (everything before - Parameters:)
            let summaryLines = Array(docLines[..<paramIndex])
            let summary = summaryLines.isEmpty ? nil : summaryLines.joined(separator: "\n/// ")

            // Extract parameter docs
            var paramDocs: [String: String] = [:]
            var currentParam: String?
            var currentParamLines: [String] = []

            for line in docLines[(paramIndex + 1)...] {
                if line.hasPrefix("- ") {
                    // Save previous parameter if exists
                    if let param = currentParam {
                        paramDocs[param] = currentParamLines.joined(separator: "\n///     ")
                    }
                    // Start new parameter
                    let parts = line.dropFirst(2).split(separator: ":", maxSplits: 1)
                    if parts.count == 2 {
                        currentParam = trimWhitespace(String(parts[0]))
                        currentParamLines = [trimWhitespace(String(parts[1]))]
                    }
                } else {
                    // Continuation of current parameter
                    currentParamLines.append(line)
                }
            }

            // Save last parameter
            if let param = currentParam {
                paramDocs[param] = currentParamLines.joined(separator: "\n///     ")
            }

            return (summary, paramDocs)
        }()

        // Generate parameter documentation using Arguments init param docs
        let parameterDocs = properties.map { property in
            if let doc = argumentsParamDocs[property.name] {
                // Use the parameter documentation from Arguments init
                return "///   - \(property.name): \(doc)"
            } else if let doc = property.doc {
                // Fall back to property documentation
                return "///   - \(property.name): \(doc)"
            } else {
                // Last resort: just the type
                return "///   - \(property.name): \(property.type.trimmed)"
            }
        }.joined(separator: "\n")

        // Extract throws documentation from parent struct's init (the one that takes Arguments)
        let throwsDocs: String = {
            if !hasThrowingInit {
                return ""
            }

            // Find the parent struct's init that takes the Arguments struct
            let parentInits = declaration.memberBlock.members
                .compactMap { $0.decl.as(InitializerDeclSyntax.self) }

            for parentInit in parentInits {
                // Check if it throws
                guard parentInit.signature.effectSpecifiers?.throwsClause != nil else {
                    continue
                }

                // Extract its documentation
                let trivia = parentInit.leadingTrivia
                var docLines: [String] = []

                for piece in trivia {
                    switch piece {
                    case .docLineComment(let text):
                        let cleaned = trimWhitespace(text.trimmingPrefix("///"))
                        docLines.append(cleaned)
                    case .docBlockComment(let text):
                        let lines =
                            text
                            .trimmingPrefix("/**")
                            .trimmingSuffix("*/")
                            .split(separator: "\n")
                            .map { line -> String in
                                let trimmed = trimWhitespace(String(line))
                                return trimWhitespace(trimmed.trimmingPrefix("*"))
                            }
                        docLines.append(contentsOf: lines)
                    default:
                        break
                    }
                }

                // Find "- Throws:" line
                for line in docLines where line.hasPrefix("- Throws:") {
                    let throwsText = trimWhitespace(String(line.dropFirst("- Throws:".count)))
                    return "\n/// - Throws: \(throwsText)"
                }
            }

            // Fallback if no throws documentation found
            return "\n/// - Throws: Error if initialization fails."
        }()

        // Use Arguments init doc if available, otherwise use generic description
        let summaryDoc: String
        if let initDoc = argumentsInitDoc {
            summaryDoc = "/// \(initDoc)"
        } else {
            summaryDoc = """
                /// Initializer accepting ``\(structName)`` properties as individual parameters.
                ///
                /// This initializer provides direct parameter access without explicitly creating
                /// a ``\(structName)`` instance.
                """
        }

        // Generate the convenience initializer with comprehensive DocC comments
        let initializer: DeclSyntax = """
            \(raw: discardableResultAttr)\(raw: summaryDoc)
            ///
            /// - Parameters:
            \(raw: parameterDocs)\(raw: throwsDocs)
            public init(
                \(raw: parameters.map { "\($0)" }.joined(separator: ",\n    "))
            ) \(raw: throwsClause) {
                \(raw: tryKeyword)self.init(\(raw: structName)(
                    \(raw: argumentsCallArgs)
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

// String helpers for doc comment extraction
extension String {
    func trimmingPrefix(_ prefix: String) -> String {
        guard hasPrefix(prefix) else { return self }
        return String(dropFirst(prefix.count))
    }

    func trimmingSuffix(_ suffix: String) -> String {
        guard hasSuffix(suffix) else { return self }
        return String(dropLast(suffix.count))
    }
}
