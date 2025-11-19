// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "IronSourceSDKWrapper",
    platforms: [
        .iOS(.v12)
    ],
    products: [
        .library(
            name: "IronSourceSDKWrapper",
            targets: ["IronSourceSDKWrapper"]
        )
    ],
    targets: [
        .binaryTarget(
            name: "IronSource",
            path: "Frameworks/IronSourceSDK.xcframework"
        ),
        .target(
            name: "IronSourceSDKWrapper",
            dependencies: ["IronSource"],
            path: "Sources/IronSourceSDKWrapper",
            publicHeadersPath: "include",
            cSettings: [
                .headerSearchPath("include"),
            ]
        )
    ]
)

