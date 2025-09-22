// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "MSPiOSCore",
    platforms: [
        .iOS(.v15)
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "MSPiOSCore",
            targets: ["MSPiOSCore"]),
    ],
    dependencies: [
        // No external dependencies for MSPiOSCore
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        .target(
            name: "MSPiOSCore",
            dependencies: [],
            path: "MSPiOSCore",
            publicHeadersPath: ".",
            cSettings: [
                .headerSearchPath("."),
            ],
            swiftSettings: [
                .define("SWIFT_PACKAGE"),
            ]
        ),
        .testTarget(
            name: "MSPiOSCoreTests",
            dependencies: ["MSPiOSCore"],
            path: "MSPiOSCoreTests"
        ),
    ]
)
