// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "PubmaticAdapter",
    platforms: [
        .iOS(.v15)
    ],
    products: [
        .library(
            name: "PubmaticAdapter",
            targets: ["PubmaticAdapter"]
        )
    ],
    dependencies: [
        .package(path: "../MSPiOSCore"),
        .package(path: "../MSPSharedLibraries"),
        .package(path: "../OpenWrapSDKWrapper"),
    ],
    targets: [
        .target(
            name: "PubmaticAdapter",
            dependencies: [
                .product(name: "MSPiOSCore", package: "mspioscore"),
                .product(name: "MSPSharedLibraries", package: "MSPSharedLibraries"),
                .product(name: "OpenWrapSDKWrapper", package: "OpenWrapSDKWrapper"),
            ],
            path: "PubmaticAdapter",
            publicHeadersPath: ".",
            cSettings: [
                .headerSearchPath("."),
            ],
            swiftSettings: [
                .define("SWIFT_PACKAGE"),
            ]
        )
    ]
)
