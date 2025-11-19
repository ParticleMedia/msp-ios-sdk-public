// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "MSPFacebookAdapter",
    platforms: [
        .iOS(.v15)
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "MSPFacebookAdapter",
            targets: ["MSPFacebookAdapter"]),
    ],
    dependencies: [
        // External dependencies
        // Internal dependencies
        .package(path: "../MSPiOSCore"),
        .package(path: "../MSPSharedLibraries"),
        .package(path: "../FBAudienceNetworkWrapper"),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        .target(
            name: "MSPFacebookAdapter",
            dependencies: [
                .product(name: "MSPiOSCore", package: "mspioscore"),
                .product(name: "MSPSharedLibraries", package: "MSPSharedLibraries"),
                .product(name: "FBAudienceNetworkWrapper", package: "FBAudienceNetworkWrapper"),
            ],
            path: "MSPFacebookAdapter",
            exclude: ["FacebookAdapter.docc"],
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
    ]
)
