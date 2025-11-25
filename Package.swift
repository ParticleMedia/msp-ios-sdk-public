// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "msp-ios-sdk",
    platforms: [
        .iOS(.v15)
    ],
    products: [
        // Core modules (binary)
        .library(name: "MSPCore", targets: ["MSPCore"]),
        .library(name: "MSPiOSCore", targets: ["MSPiOSCore"]),
        .library(name: "NovaCore", targets: ["NovaCore"]),
        .library(name: "MSPSharedLibraries", targets: ["MSPSharedLibraries"]),
        .library(name: "MSPOMSDK", targets: ["MSPOMSDK"]),
        
        // Adapter modules (source)
        .library(name: "MSPGoogleAdapter", targets: ["MSPGoogleAdapter"]),
        .library(name: "MSPFacebookAdapter", targets: ["MSPFacebookAdapter"]),
        .library(name: "MSPPrebidAdapter", targets: ["MSPPrebidAdapter"]),
        .library(name: "NovaAdapter", targets: ["NovaAdapter"]),
        .library(name: "UnityAdapter", targets: ["UnityAdapter"]),
        .library(name: "InmobiAdapter", targets: ["InmobiAdapter"]),
        .library(name: "MintegralAdapter", targets: ["MintegralAdapter"]),
        .library(name: "MobilefuseAdapter", targets: ["MobilefuseAdapter"]),
        .library(name: "PubmaticAdapter", targets: ["PubmaticAdapter"]),
        .library(name: "AmazonAdapter", targets: ["AmazonAdapter"])
    ],
    dependencies: [
        // Third-party Ads SDKs (via CocoaPods or SPM if available)
        // Note: Most Ads SDKs are only available via CocoaPods
        // For SPM-only usage, these would need to be binary targets or wrappers
    ],
    targets: [
        // Core modules as binary targets
        .binaryTarget(
            name: "MSPCore",
            path: "Build/XCFrameworks/MSPCore.xcframework"
        ),
        .binaryTarget(
            name: "MSPiOSCore",
            path: "Build/XCFrameworks/MSPiOSCore.xcframework"
        ),
        .binaryTarget(
            name: "NovaCore",
            path: "Build/XCFrameworks/NovaCore.xcframework"
        ),
        .binaryTarget(
            name: "MSPSharedLibraries",
            path: "Build/XCFrameworks/MSPSharedLibraries.xcframework"
        ),
        .binaryTarget(
            name: "MSPOMSDK",
            path: "Build/XCFrameworks/MSPOMSDK.xcframework"
        ),
        
        // Adapter modules as source targets
        .target(
            name: "MSPGoogleAdapter",
            dependencies: [
                "MSPSharedLibraries"
                // Google-Mobile-Ads-SDK and PrebidMobile would need to be added
                // as dependencies if available via SPM, otherwise use CocoaPods
            ],
            path: "Sources/Adapters/MSPGoogleAdapter/MSPGoogleAdapter"
        ),
        .target(
            name: "MSPFacebookAdapter",
            dependencies: [
                "MSPSharedLibraries"
                // FBAudienceNetwork and PrebidMobile would need to be added
            ],
            path: "Sources/Adapters/MSPFacebookAdapter/MSPFacebookAdapter"
        ),
        .target(
            name: "MSPPrebidAdapter",
            dependencies: [
                "MSPSharedLibraries",
                "MSPiOSCore"
            ],
            path: "Sources/Adapters/MSPPrebidAdapter/MSPPrebidAdapter"
        ),
        .target(
            name: "NovaAdapter",
            dependencies: [
                "MSPSharedLibraries",
                "MSPOMSDK"
            ],
            path: "Sources/Adapters/NovaAdapter/NovaAdapter"
        ),
        .target(
            name: "UnityAdapter",
            dependencies: [
                "MSPSharedLibraries"
                // IronSourceSDK would need to be added
            ],
            path: "Sources/Adapters/UnityAdapter/UnityAdapter"
        ),
        .target(
            name: "InmobiAdapter",
            dependencies: [
                "MSPSharedLibraries"
                // InMobiSDK would need to be added
            ],
            path: "Sources/Adapters/InmobiAdapter/InmobiAdapter"
        ),
        .target(
            name: "MintegralAdapter",
            dependencies: [
                "MSPSharedLibraries"
                // MintegralAdSDK and PrebidMobile would need to be added
            ],
            path: "Sources/Adapters/MintegralAdapter/MintegralAdapter"
        ),
        .target(
            name: "MobilefuseAdapter",
            dependencies: [
                "MSPSharedLibraries"
                // MobileFuseSDK and PrebidMobile would need to be added
            ],
            path: "Sources/Adapters/MobilefuseAdapter/MobilefuseAdapter"
        ),
        .target(
            name: "PubmaticAdapter",
            dependencies: [
                "MSPSharedLibraries"
                // OpenWrapSDK and PrebidMobile would need to be added
            ],
            path: "Sources/Adapters/PubmaticAdapter/PubmaticAdapter"
        ),
        .target(
            name: "AmazonAdapter",
            dependencies: [
                "MSPSharedLibraries"
                // Google-Mobile-Ads-SDK, AmazonPublisherServicesSDK would need to be added
            ],
            path: "Sources/Adapters/AmazonAdapter/AmazonAdapter"
        )
    ]
)

