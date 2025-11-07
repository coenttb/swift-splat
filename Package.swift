// swift-tools-version: 6.0
import PackageDescription
import CompilerPluginSupport

let package = Package(
    name: "swift-splat",
    platforms: [
        .macOS(.v15),
        .iOS(.v18)
    ],
    products: [
        .library(
            name: "Splat",
            targets: ["Splat"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-syntax.git", from: "600.0.0"),
        .package(url: "https://github.com/pointfreeco/swift-macro-testing.git", from: "0.5.2")
    ],
    targets: [
        // Macro implementation (regular target, not macro target)
        .target(
            name: "SplatMacros",
            dependencies: [
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax")
            ]
        ),

        // Compiler plugin (macro target)
        .macro(
            name: "SplatPlugin",
            dependencies: [
                "SplatMacros",
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax")
            ]
        ),

        // Library that exposes the macro
        .target(
            name: "Splat",
            dependencies: ["SplatPlugin"]
        ),

        // Tests
        .testTarget(
            name: "SplatTests",
            dependencies: [
                "Splat",
                "SplatMacros",
                .product(name: "MacroTesting", package: "swift-macro-testing")
            ]
        )
    ]
)
