// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "MSPGoogleAdapter",
    platforms: [
        .iOS(.v15)
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "MSPGoogleAdapter",
            targets: ["MSPGoogleAdapter"]),
    ],
    dependencies: [
        // External dependencies
        .package(url: "https://github.com/googleads/swift-package-manager-google-mobile-ads.git", from: "10.14.0"),
        // Internal dependencies
        .package(path: "../MSPiOSCore"),
        .package(path: "../MSPSharedLibraries"),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        .target(
            name: "MSPGoogleAdapter",
            dependencies: [
                .product(name: "GoogleMobileAds", package: "swift-package-manager-google-mobile-ads"),
                .product(name: "MSPiOSCore", package: "mspioscore"),
                .product(name: "MSPSharedLibraries", package: "MSPSharedLibraries"),
            ],
            path: "MSPGoogleAdapter",
            exclude: ["GoogleAdapter.docc"],
            sources: [
                "MSPGoogleAdsTypes.swift",
                "GoogleAdapter.swift",
                "GoogleBidder.swift",
                "GoogleManager.swift",
                "GoogleQueryInfoFetcherHelper.swift",
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
