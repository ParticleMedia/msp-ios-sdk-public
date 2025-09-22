// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "PrebidAdapter",
    platforms: [
        .iOS(.v15)
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "PrebidAdapter",
            targets: ["PrebidAdapter"]),
    ],
    dependencies: [
        // Internal dependencies
        .package(path: "../MSPSharedLibraries"),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        .target(
            name: "PrebidAdapter",
            dependencies: [
                .product(name: "MSPSharedLibraries", package: "mspsharedlibraries")
            ],
            path: "PrebidAdapter",
            sources: [
                "PrebidAdapter.swift",
                "PrebidBidLoader.swift",
                "Interstitial/"
            ],
            publicHeadersPath: ".",
            cSettings: [
                .headerSearchPath("."),
            ],
            swiftSettings: [
                .define("SWIFT_PACKAGE"),
            ]
        ),
        .testTarget(
            name: "PrebidAdapterTests",
            dependencies: ["PrebidAdapter"],
            path: "PrebidAdapterTests"
        ),
    ]
)
