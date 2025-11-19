// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "UnityAdapter",
    platforms: [
        .iOS(.v15)
    ],
    products: [
        .library(
            name: "UnityAdapter",
            targets: ["UnityAdapter"]
        )
    ],
    dependencies: [
        .package(path: "../MSPiOSCore"),
        .package(path: "../MSPSharedLibraries"),
        .package(path: "../IronSourceSDKWrapper"),
    ],
    targets: [
        .target(
            name: "UnityAdapter",
            dependencies: [
                .product(name: "MSPiOSCore", package: "mspioscore"),
                .product(name: "MSPSharedLibraries", package: "MSPSharedLibraries"),
                .product(name: "IronSourceSDKWrapper", package: "IronSourceSDKWrapper"),
            ],
            path: "UnityAdapter",
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
