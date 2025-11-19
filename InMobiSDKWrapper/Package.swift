// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "InMobiSDKWrapper",
    platforms: [
        .iOS(.v12)
    ],
    products: [
        .library(
            name: "InMobiSDKWrapper",
            targets: ["InMobiSDKWrapper"]
        )
    ],
    targets: [
        .binaryTarget(
            name: "InMobiSDK",
            path: "Frameworks/InMobiSDK.xcframework"
        ),
        .target(
            name: "InMobiSDKWrapper",
            dependencies: ["InMobiSDK"],
            path: "Sources/InMobiSDKWrapper",
            publicHeadersPath: "include",
            cSettings: [
                .headerSearchPath("include"),
            ]
        )
    ]
)
