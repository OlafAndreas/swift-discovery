// swift-tools-version: 6.1
import PackageDescription
import CompilerPluginSupport

let package = Package(
    name: "SwiftDiscovery",
    platforms: [.macOS(.v13), .iOS(.v16), .tvOS(.v16), .watchOS(.v9), .visionOS(.v1)],
    products: [
        /// Runtime API and the `@Discoverable(Key.self)` macro.
        .library(name: "SwiftDiscovery", targets: ["SwiftDiscovery"]),
        /// Runtime API only. Builds without swift-syntax; records come from other modules' macros.
        .library(name: "SwiftDiscoveryCore", targets: ["SwiftDiscoveryCore"]),
        /// SwiftSyntax helpers for framework macros that want to emit discovery records.
        .library(name: "SwiftDiscoveryMacroSupport", targets: ["SwiftDiscoveryMacroSupport"]),
    ],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-syntax.git", "600.0.0"..<"606.0.0-latest"),
        .package(url: "https://github.com/OlafAndreas/swift-sections.git", from: "0.2.0"),
    ],
    targets: [
        .target(
            name: "SwiftDiscoveryCore",
            dependencies: [
                .product(name: "SwiftSections", package: "swift-sections"),
            ]
        ),
        .target(
            name: "SwiftDiscovery",
            dependencies: [
                "SwiftDiscoveryCore",
                "SwiftDiscoveryMacros",
            ]
        ),
        // Syntax builders shared by `@Discoverable` and third-party macros such as SwiftMediator's `@Handler`.
        .target(
            name: "SwiftDiscoveryMacroSupport",
            dependencies: [
                .product(name: "SwiftSyntax", package: "swift-syntax"),
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                .product(name: "SwiftDiagnostics", package: "swift-syntax"),
            ]
        ),
        .macro(
            name: "SwiftDiscoveryMacros",
            dependencies: [
                "SwiftDiscoveryMacroSupport",
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
            ]
        ),
        .testTarget(
            name: "SwiftDiscoveryTests",
            dependencies: ["SwiftDiscovery"],
            swiftSettings: [.unsafeFlags(["-strict-memory-safety", "-warnings-as-errors"])]
        ),
        .testTarget(
            name: "SwiftDiscoveryMacrosTests",
            dependencies: [
                "SwiftDiscoveryMacros",
                .product(name: "SwiftSyntaxMacrosTestSupport", package: "swift-syntax"),
            ]
        ),
    ]
)
