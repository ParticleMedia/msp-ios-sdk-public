// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "InmobiAdapter",
    platforms: [
        .iOS(.v15)
    ],
    products: [
        .library(
            name: "InmobiAdapter",
            targets: ["InmobiAdapter"]
        )
    ],
    dependencies: [
        .package(path: "../MSPiOSCore"),
        .package(path: "../MSPSharedLibraries"),
        .package(path: "../InMobiSDKWrapper"),
    ],
    targets: [
        .target(
            name: "InmobiAdapter",
            dependencies: [
                .product(name: "MSPiOSCore", package: "mspioscore"),
                .product(name: "MSPSharedLibraries", package: "MSPSharedLibraries"),
                .product(name: "InMobiSDKWrapper", package: "InMobiSDKWrapper"),
            ],
            path: "InmobiAdapter",
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
