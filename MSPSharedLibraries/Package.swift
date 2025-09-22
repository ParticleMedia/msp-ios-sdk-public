// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "MSPSharedLibraries",
    platforms: [
        .iOS(.v15)
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "MSPSharedLibraries",
            targets: ["MSPSharedLibraries"]),
    ],
    dependencies: [
        // Internal dependencies
        .package(path: "../MSPiOSCore"),
    ],
    targets: [
        // Binary targets for XCFrameworks (only PrebidMobile remains as binary)
        .binaryTarget(
            name: "PrebidMobile",
            path: "PrebidMobile.xcframework"
        ),
        
        // Wrapper target that combines source and binary frameworks
        .target(
            name: "MSPSharedLibraries",
            dependencies: [
                "PrebidMobile",
                .product(name: "MSPiOSCore", package: "mspioscore")
            ],
            path: "MSPSharedLibraries",
            sources: [
                "MSPSharedLibraries.swift"
            ],
            publicHeadersPath: ".",
            cSettings: [
                .headerSearchPath("."),
                .headerSearchPath("PrebidMobile.xcframework/Headers"),
            ],
            swiftSettings: [
                .define("SWIFT_PACKAGE"),
            ]
        ),
        .testTarget(
            name: "MSPSharedLibrariesTests",
            dependencies: ["MSPSharedLibraries"],
            path: "MSPSharedLibrariesTests"
        ),
    ]
)
