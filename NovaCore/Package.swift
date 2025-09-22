// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "NovaCore",
    platforms: [
        .iOS(.v15)
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "NovaCore",
            targets: ["NovaCore"]),
    ],
    dependencies: [
        // External dependencies
        .package(url: "https://github.com/onevcat/Kingfisher.git", from: "7.0.0"),
        .package(url: "https://github.com/SnapKit/SnapKit.git", from: "5.6.0"),
        
        // Internal dependencies
        .package(path: "../MSPiOSCore"),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        .target(
            name: "NovaCore",
            dependencies: [
                "MSPiOSCore",
                .product(name: "Kingfisher", package: "Kingfisher"),
                .product(name: "SnapKit", package: "SnapKit")
            ],
            path: "NovaCore",
            publicHeadersPath: ".",
            resources: [
                .process("NBAssets.xcassets"),
                .process("NBResourceBundle.bundle")
            ],
            cSettings: [
                .headerSearchPath("."),
            ],
            swiftSettings: [
                .define("SWIFT_PACKAGE"),
            ]
        ),
        .testTarget(
            name: "NovaCoreTests",
            dependencies: ["NovaCore"],
            path: "NovaCoreTests"
        ),
    ]
)
