// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MobilefuseAdapter",
    platforms: [
        .iOS(.v15)
    ],
    products: [
        .library(
            name: "MobilefuseAdapter",
            targets: ["MobilefuseAdapter"]
        )
    ],
    dependencies: [
        .package(path: "../MSPiOSCore"),
        .package(path: "../MSPSharedLibraries"),
        .package(path: "../MobileFuseSDKWrapper"),
    ],
    targets: [
        .target(
            name: "MobilefuseAdapter",
            dependencies: [
                .product(name: "MSPiOSCore", package: "mspioscore"),
                .product(name: "MSPSharedLibraries", package: "MSPSharedLibraries"),
                .product(name: "MobileFuseSDKWrapper", package: "MobileFuseSDKWrapper"),
            ],
            path: "MobilefuseAdapter",
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
