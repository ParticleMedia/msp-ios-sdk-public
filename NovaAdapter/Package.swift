// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "NovaAdapter",
    platforms: [
        .iOS(.v15)
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "NovaAdapter",
            targets: ["NovaAdapter"]),
    ],
    dependencies: [
        // External dependencies
        .package(url: "https://github.com/onevcat/Kingfisher.git", from: "7.0.0"),
        .package(url: "https://github.com/SnapKit/SnapKit.git", from: "5.6.0"),
        
        // Internal dependencies
        .package(path: "../MSPSharedLibraries"),
        .package(path: "../MSPOMSDK"),
    ],
    targets: [
        // Binary target for NovaCore XCFramework
        .binaryTarget(
            name: "NovaCoreBinary",
            path: "NovaCore.xcframework"
        ),
        
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        .target(
            name: "NovaAdapter",
            dependencies: [
                .product(name: "Kingfisher", package: "Kingfisher"),
                .product(name: "SnapKit", package: "SnapKit"),
                .product(name: "MSPSharedLibraries", package: "mspsharedlibraries"),
                "MSPOMSDK",
                "NovaCoreBinary"
            ],
            path: "NovaAdapter",
            publicHeadersPath: ".",
            cSettings: [
                .headerSearchPath("."),
            ],
            swiftSettings: [
                .define("SWIFT_PACKAGE"),
            ]
        ),
        .testTarget(
            name: "NovaAdapterTests",
            dependencies: ["NovaAdapter"],
            path: "NovaAdapterTests"
        ),
        
    ]
)
