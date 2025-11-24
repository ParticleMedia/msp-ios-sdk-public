// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MintegralAdSDKWrapper",
    platforms: [
        .iOS(.v12)
    ],
    products: [
        .library(
            name: "MintegralAdSDKWrapper",
            targets: ["MintegralAdSDKWrapper"]
        )
    ],
    targets: [
        .binaryTarget(
            name: "MTGSDK",
            path: "Frameworks/MintegralAdSDK.xcframework"
        ),
        .target(
            name: "MintegralAdSDKWrapper",
            dependencies: ["MTGSDK"],
            path: "Sources/MintegralAdSDKWrapper",
            publicHeadersPath: "include",
            cSettings: [
                .headerSearchPath("include"),
            ]
        )
    ]
)
