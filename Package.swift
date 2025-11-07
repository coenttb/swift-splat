// swift-tools-version: 6.2
import CompilerPluginSupport
import PackageDescription

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
        .package(url: "https://github.com/swiftlang/swift-syntax.git", "600.0.0"..<"603.0.0"),
        .package(url: "https://github.com/pointfreeco/swift-macro-testing.git", from: "0.5.2")
    ],
    targets: [
        // Compiler plugin with macro implementation
        .macro(
            name: "SplatPlugin",
            dependencies: [
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
                .product(name: "MacroTesting", package: "swift-macro-testing")
            ]
        )
    ]
)
