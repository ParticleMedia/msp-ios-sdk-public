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
            path: "Frameworks/MTGSDK.xcframework"
        ),
        .binaryTarget(
            name: "MTGSDKBanner",
            path: "Frameworks/MTGSDKBanner.xcframework"
        ),
        .binaryTarget(
            name: "MTGSDKNewInterstitial",
            path: "Frameworks/MTGSDKNewInterstitial.xcframework"
        ),
        .binaryTarget(
            name: "MTGSDKBidding",
            path: "Frameworks/MTGSDKBidding.xcframework"
        ),
        .binaryTarget(
            name: "MTGSDKInterstitialVideo",
            path: "Frameworks/MTGSDKInterstitialVideo.xcframework"
        ),
        .target(
            name: "MintegralAdSDKWrapper",
            dependencies: ["MTGSDK", "MTGSDKBanner", "MTGSDKNewInterstitial", "MTGSDKBidding", "MTGSDKInterstitialVideo"],
            path: "Sources/MintegralAdSDKWrapper",
            publicHeadersPath: "include",
            cSettings: [
                .headerSearchPath("include"),
            ]
        )
    ]
)
