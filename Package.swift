// swift-tools-version: 6.1
import PackageDescription
import CompilerPluginSupport

let package = Package(
    name: "SwiftDiscovery",
    platforms: [.macOS(.v13), .iOS(.v16), .tvOS(.v16), .watchOS(.v9), .visionOS(.v1)],
    products: [
        /// Runtime API and the `@Discoverable(Key.self)` macro.
        .library(name: "SwiftDiscovery", targets: ["SwiftDiscovery"]),
        /// SwiftSyntax helpers for framework macros that want to emit discovery records.
        .library(name: "SwiftDiscoveryMacroSupport", targets: ["SwiftDiscoveryMacroSupport"]),
    ],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-syntax.git", "600.0.0"..<"605.0.0"),
    ],
    targets: [
        .target(
            name: "SwiftDiscovery",
            dependencies: [
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
        .testTarget(name: "SwiftDiscoveryTests", dependencies: ["SwiftDiscovery"]),
        .testTarget(
            name: "SwiftDiscoveryMacrosTests",
            dependencies: [
                "SwiftDiscoveryMacros",
                .product(name: "SwiftSyntaxMacrosTestSupport", package: "swift-syntax"),
            ]
        ),
    ]
)
