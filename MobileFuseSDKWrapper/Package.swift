// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MobileFuseSDKWrapper",
    platforms: [
        .iOS(.v12)
    ],
    products: [
        .library(
            name: "MobileFuseSDKWrapper",
            targets: ["MobileFuseSDKWrapper"]
        )
    ],
    targets: [
        .binaryTarget(
            name: "MobileFuseSDK",
            path: "Frameworks/MobileFuseSDK.xcframework"
        ),
        .target(
            name: "MobileFuseSDKWrapper",
            dependencies: ["MobileFuseSDK"],
            path: "Sources/MobileFuseSDKWrapper",
            publicHeadersPath: "include",
            cSettings: [
                .headerSearchPath("include"),
            ]
        )
    ]
)
