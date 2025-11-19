// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "MSPOMSDK",
    platforms: [
        .iOS(.v15)
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "MSPOMSDK",
            targets: ["MSPOMSDK"]),
    ],
    dependencies: [
        // No external dependencies for OMSDK
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        .target(
            name: "MSPOMSDK",
            dependencies: [
                "OMSDK_Newsbreak1"
            ],
            path: "MSPOMSDK",
            exclude: ["MSPOMSDK.docc"],
            sources: [
                "Shim.swift"
            ],
            publicHeadersPath: ".",
            cSettings: [
                .headerSearchPath("."),
                .headerSearchPath("OMSDK_Newsbreak1.xcframework/Headers"),
            ],
            swiftSettings: [
                .define("SWIFT_PACKAGE"),
            ]
        ),
        .testTarget(
            name: "MSPOMSDKTests",
            dependencies: ["MSPOMSDK"],
            path: "MSPOMSDKTests"
        ),
        
        // Binary target for OMSDK XCFramework
        .binaryTarget(
            name: "OMSDK_Newsbreak1",
            path: "OMSDK_Newsbreak1.xcframework"
        ),
    ]
)
