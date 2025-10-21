// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "FacebookAdapter",
    platforms: [
        .iOS(.v15)
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "FacebookAdapter",
            targets: ["FacebookAdapter"]),
    ],
    dependencies: [
        // External dependencies
        .package(url: "https://github.com/facebook/facebook-ios-sdk.git", from: "16.0.0"),
        
        // Internal dependencies
        .package(path: "../MSPiOSCore"),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        .target(
            name: "FacebookAdapter",
            dependencies: [
                .product(name: "FacebookCore", package: "facebook-ios-sdk"),
                .product(name: "MSPiOSCore", package: "mspioscore"),
            ],
            path: "FacebookAdapter",
            sources: [
                "FacebookAdapter.swift",
                "FacebookBidTokenProviderHelper.swift",
                "FacebookManager.swift",
                "Interstitial/",
                "Native/"
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
            name: "FacebookAdapterTests",
            dependencies: ["FacebookAdapter"],
            path: "FacebookAdapterTests"
        ),
    ]
)
