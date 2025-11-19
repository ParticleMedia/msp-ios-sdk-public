// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "NovaCore",
    platforms: [
        .iOS(.v15),
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "NovaCore",
            targets: ["NovaCore"]
        ),
    ],
    dependencies: [
        // External dependencies
        .package(url: "https://github.com/onevcat/Kingfisher.git", from: "7.0.0"),
        .package(url: "https://github.com/SnapKit/SnapKit.git", from: "5.6.0"),
        .package(url: "https://github.com/airbnb/lottie-ios.git", from: "4.0.0"),
        .package(path: "../ShimmerWrapper"),

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
                .product(name: "SnapKit", package: "SnapKit"),
                .product(name: "Lottie", package: "lottie-ios"),
                .product(name: "ShimmerWrapper", package: "ShimmerWrapper"),
            ],
            path: "NovaCore",
            exclude: [
                "NBResourceBundle.bundle/Info.plist"
            ],
            sources: nil,
            resources: [
                .copy("NBResourceBundle.bundle"),
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
            name: "NovaCoreTests",
            dependencies: ["NovaCore"],
            path: "NovaCoreTests"
        ),
    ]
)
