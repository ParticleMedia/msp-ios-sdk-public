// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "OpenWrapSDKWrapper",
    platforms: [
        .iOS(.v12)
    ],
    products: [
        .library(
            name: "OpenWrapSDKWrapper",
            targets: ["OpenWrapSDKWrapper"]
        )
    ],
    targets: [
        .binaryTarget(
            name: "OpenWrapSDK",
            path: "Frameworks/OpenWrapSDK.xcframework"
        ),
        .target(
            name: "OpenWrapSDKWrapper",
            dependencies: ["OpenWrapSDK"],
            path: "Sources/OpenWrapSDKWrapper",
            publicHeadersPath: "include",
            cSettings: [
                .headerSearchPath("include"),
            ]
        )
    ]
)
