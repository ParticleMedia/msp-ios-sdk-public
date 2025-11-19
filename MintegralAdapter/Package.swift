// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MintegralAdapter",
    platforms: [
        .iOS(.v15)
    ],
    products: [
        .library(
            name: "MintegralAdapter",
            targets: ["MintegralAdapter"]
        )
    ],
    dependencies: [
        .package(path: "../MSPiOSCore"),
        .package(path: "../MSPSharedLibraries"),
        .package(path: "../MintegralAdSDKWrapper"),
    ],
    targets: [
        .target(
            name: "MintegralAdapter",
            dependencies: [
                .product(name: "MSPiOSCore", package: "mspioscore"),
                .product(name: "MSPSharedLibraries", package: "MSPSharedLibraries"),
                .product(name: "MintegralAdSDKWrapper", package: "MintegralAdSDKWrapper"),
            ],
            path: "MintegralAdapter",
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
