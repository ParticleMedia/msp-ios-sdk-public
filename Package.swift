// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

// ═══════════════════════════════════════════════════════════════════════════════
// MSP iOS SDK - Swift Package Manager Configuration
// ═══════════════════════════════════════════════════════════════════════════════
//
// This Package.swift is designed for local development with path-based binary targets.
// For remote distribution, replace local paths with URL + checksum pairs.
//
// Canonical Paths:
// - Core XCFrameworks:     Build/XCFrameworks/<Module>.xcframework
// - Third-party SDKs:      ThirdParty/<SDKName>/<SDKName>.xcframework
// - Adapter Sources:       Sources/Adapters/<AdapterName>/<AdapterName>/
//
// ═══════════════════════════════════════════════════════════════════════════════

let package = Package(
    name: "msp-ios-sdk",
    platforms: [
        .iOS(.v15)
    ],
    
    // ═══════════════════════════════════════════════════════════════════════════
    // MARK: - PRODUCTS (16 total)
    // ═══════════════════════════════════════════════════════════════════════════
    products: [
        // ───────────────────────────────────────────────────────────────────────
        // Top-level SDK Product
        // Use this for basic SDK integration without specifying individual adapters
        // MSPCoreLinker ensures SwiftProtobuf is linked with MSPCore
        // ───────────────────────────────────────────────────────────────────────
        .library(
            name: "MSPAds",
            targets: ["MSPCoreLinker", "MSPSharedLibraries", "MSPiOSCore"]
        ),
        
        // ───────────────────────────────────────────────────────────────────────
        // Core Module Products (5) - Binary XCFrameworks
        // ───────────────────────────────────────────────────────────────────────
        .library(name: "MSPSharedLibraries", targets: ["MSPSharedLibraries"]),
        .library(name: "MSPiOSCore", targets: ["MSPiOSCore"]),
        .library(name: "NovaCore", targets: ["NovaCore"]),
        .library(name: "NovaCoreLinker", targets: ["NovaCoreLinker"]),  // NovaCore + Lottie
        .library(name: "MSPCore", targets: ["MSPCore"]),
        .library(name: "MSPCoreLinker", targets: ["MSPCoreLinker"]),  // MSPCore + SwiftProtobuf
        
        // ───────────────────────────────────────────────────────────────────────
        // Adapter Module Products (10) - Swift Source Targets
        // ───────────────────────────────────────────────────────────────────────
        .library(name: "MSPPrebidAdapter", targets: ["MSPPrebidAdapter"]),
        .library(name: "MSPGoogleAdapter", targets: ["MSPGoogleAdapter"]),
        .library(name: "MSPFacebookAdapter", targets: ["MSPFacebookAdapter"]),
        .library(name: "NovaAdapter", targets: ["NovaAdapter"]),
        .library(name: "AmazonAdapter", targets: ["AmazonAdapter"]),
        .library(name: "UnityAdapter", targets: ["UnityAdapter"]),
        .library(name: "InmobiAdapter", targets: ["InmobiAdapter"]),
        .library(name: "MobilefuseAdapter", targets: ["MobilefuseAdapter"]),
        .library(name: "MintegralAdapter", targets: ["MintegralAdapter"]),
        .library(name: "PubmaticAdapter", targets: ["PubmaticAdapter"]),
    ],
    
    // ═══════════════════════════════════════════════════════════════════════════
    // MARK: - EXTERNAL DEPENDENCIES (SPM-native packages)
    // ═══════════════════════════════════════════════════════════════════════════
    dependencies: [
        // Google Mobile Ads SDK - Required by MSPGoogleAdapter, AmazonAdapter
        .package(
            url: "https://github.com/googleads/swift-package-manager-google-mobile-ads.git",
            from: "11.0.0"
        ),
        
        // SnapKit - Required by NovaAdapter
        .package(
            url: "https://github.com/SnapKit/SnapKit.git",
            from: "5.7.0"
        ),
        
        // Kingfisher - Required by NovaAdapter
        .package(
            url: "https://github.com/onevcat/Kingfisher.git",
            from: "8.0.0"
        ),
        
        // SwiftProtobuf - Required by MSPCore (runtime dependency)
        // MUST match CocoaPods version in Podfile (1.28.2)
        .package(
            url: "https://github.com/apple/swift-protobuf.git",
            exact: "1.28.2"
        ),
        
        // Lottie - Required by NovaCore (runtime dependency)
        // MUST match CocoaPods version in Podfile (4.5.2)
        .package(
            url: "https://github.com/airbnb/lottie-ios.git",
            exact: "4.5.2"
        ),
    ],
    
    // ═══════════════════════════════════════════════════════════════════════════
    // MARK: - TARGETS
    // ═══════════════════════════════════════════════════════════════════════════
    targets: [
        
        // ═══════════════════════════════════════════════════════════════════════
        // SECTION 1: CORE MODULES - Binary XCFrameworks (5)
        // ═══════════════════════════════════════════════════════════════════════
        // These are pre-compiled frameworks with all internal dependencies baked in.
        // MSPCore uses @_implementationOnly import for adapters - not exposed to consumers.
        
        .binaryTarget(
            name: "MSPSharedLibraries",
            path: "Build/XCFrameworks/MSPSharedLibraries.xcframework"
        ),
        
        .binaryTarget(
            name: "MSPiOSCore",
            path: "Build/XCFrameworks/MSPiOSCore.xcframework"
        ),
        
        .binaryTarget(
            name: "NovaCore",
            url: "https://github.com/ParticleMedia/msp-ios-sdk-public/releases/download/0.3.0-rc.5/NovaCore.xcframework.zip",
            checksum: "60b301814e9f265dc24f5b45956c1677b5d0e0fb05b21bd1ccc341f36a3c1d56"
        ),
        
        /// Shimmer - Facebook shimmering effect library (Objective-C)
        /// Bundled from CocoaPods for SPM compatibility
        .target(
            name: "Shimmer",
            dependencies: [],
            path: "ThirdParty/Shimmer/Shimmer",
            publicHeadersPath: "include"
        ),
        
        /// NovaCoreLinker - ensures Lottie and Shimmer are linked with NovaCore
        /// NovaCore.xcframework has undefined Lottie/Shimmer symbols that need runtime linking
        .target(
            name: "NovaCoreLinker",
            dependencies: [
                "NovaCore",
                "Shimmer",
                .product(name: "Lottie", package: "lottie-ios"),
            ],
            path: "Sources/Common/NovaCoreWrapper"
        ),
        
        .binaryTarget(
            name: "MSPCore",
            path: "Build/XCFrameworks/MSPCore.xcframework"
        ),
        
        /// MSPCoreLinker - ensures SwiftProtobuf is linked with MSPCore
        /// MSPCore.xcframework has undefined SwiftProtobuf symbols that need runtime linking
        /// Apps should depend on MSPCoreLinker instead of MSPCore directly
        .target(
            name: "MSPCoreLinker",
            dependencies: [
                "MSPCore",
                .product(name: "SwiftProtobuf", package: "swift-protobuf"),
            ],
            path: "Sources/Common/MSPCoreWrapper"
        ),
        
        // ═══════════════════════════════════════════════════════════════════════
        // SECTION 2: THIRD-PARTY SDKs - Binary XCFrameworks (8)
        // ═══════════════════════════════════════════════════════════════════════
        // These SDKs don't have native SPM support and must be distributed as XCFrameworks.
        // Canonical path: ThirdParty/<SDKName>/<SDKName>.xcframework
        
        /// PrebidMobile - Prebid Server bidding SDK
        /// Used by: MSPPrebidAdapter
        /// Note: Same binary used by CocoaPods for Pods ↔︎ SPM compatibility
        .binaryTarget(
            name: "PrebidMobile",
            path: "ThirdParty/PrebidMobile/PrebidMobile.xcframework"
        ),
        
        /// FBAudienceNetwork - Meta Audience Network SDK
        /// Used by: MSPFacebookAdapter
        .binaryTarget(
            name: "FBAudienceNetwork",
            path: "ThirdParty/FBAudienceNetwork/FBAudienceNetwork.xcframework"
        ),
        
        /// IronSourceSDK - Unity LevelPlay / IronSource SDK
        /// Used by: UnityAdapter
        .binaryTarget(
            name: "IronSourceSDK",
            path: "ThirdParty/IronSourceSDK/IronSourceSDK.xcframework"
        ),
        
        /// InMobiSDK - InMobi advertising SDK
        /// Used by: InmobiAdapter
        .binaryTarget(
            name: "InMobiSDK",
            path: "ThirdParty/InMobiSDK/InMobiSDK.xcframework"
        ),
        
        /// MobileFuseSDK - MobileFuse advertising SDK
        /// Used by: MobilefuseAdapter
        .binaryTarget(
            name: "MobileFuseSDK",
            path: "ThirdParty/MobileFuseSDK/MobileFuseSDK.xcframework"
        ),
        
        /// Mintegral SDK - Multi-module advertising SDK
        /// Used by: MintegralAdapter
        /// Subspecs: MTGSDK (core), MTGSDKBidding, MTGSDKBanner, MTGSDKNewInterstitial
        .binaryTarget(
            name: "MTGSDK",
            path: "ThirdParty/MintegralAdSDK/MTGSDK.xcframework"
        ),
        .binaryTarget(
            name: "MTGSDKBidding",
            path: "ThirdParty/MintegralAdSDK/MTGSDKBidding.xcframework"
        ),
        .binaryTarget(
            name: "MTGSDKBanner",
            path: "ThirdParty/MintegralAdSDK/MTGSDKBanner.xcframework"
        ),
        .binaryTarget(
            name: "MTGSDKNewInterstitial",
            path: "ThirdParty/MintegralAdSDK/MTGSDKNewInterstitial.xcframework"
        ),
        .binaryTarget(
            name: "MTGSDKInterstitialVideo",
            path: "ThirdParty/MintegralAdSDK/MTGSDKInterstitialVideo.xcframework"
        ),
        
        /// OpenWrapSDK - PubMatic OpenWrap SDK
        /// Used by: PubmaticAdapter
        .binaryTarget(
            name: "OpenWrapSDK",
            path: "ThirdParty/OpenWrapSDK/OpenWrapSDK.xcframework"
        ),
        
        /// AmazonPublisherServicesSDK - Amazon APS SDK
        /// Used by: AmazonAdapter
        .binaryTarget(
            name: "AmazonPublisherServicesSDK",
            path: "ThirdParty/AmazonPublisherServicesSDK/AmazonPublisherServicesSDK.xcframework"
        ),
        
        // ═══════════════════════════════════════════════════════════════════════
        // SECTION 2.5: SHARED MODULES - Swift Source Targets
        // ═══════════════════════════════════════════════════════════════════════
        
        /// MSPGoogleAdsTypes - Abstraction layer for GoogleMobileAds SDK
        /// Provides unified API across CocoaPods and SPM builds
        /// Used by: MSPGoogleAdapter, AmazonAdapter
        .target(
            name: "MSPGoogleAdsTypes",
            dependencies: [
                .product(name: "GoogleMobileAds", package: "swift-package-manager-google-mobile-ads"),
            ],
            path: "Sources/Common/MSPGoogleAdsTypes"
        ),
        
        // ═══════════════════════════════════════════════════════════════════════
        // SECTION 3: ADAPTER MODULES - Swift Source Targets (10)
        // ═══════════════════════════════════════════════════════════════════════
        // These are compiled from source by the consumer.
        // Path: Sources/Adapters/<AdapterName>/<AdapterName>/
        
        /// MSPPrebidAdapter - Prebid Server bidding adapter
        /// Dependencies: MSPSharedLibraries, MSPiOSCore, PrebidMobile
        .target(
            name: "MSPPrebidAdapter",
            dependencies: [
                "MSPSharedLibraries",
                "MSPiOSCore",
                "PrebidMobile",
            ],
            path: "Sources/Adapters/MSPPrebidAdapter/MSPPrebidAdapter"
        ),
        
        /// MSPGoogleAdapter - Google AdMob/Ad Manager adapter
        /// Dependencies: MSPSharedLibraries, MSPiOSCore, MSPGoogleAdsTypes
        .target(
            name: "MSPGoogleAdapter",
            dependencies: [
                "MSPSharedLibraries",
                "MSPiOSCore",
                "MSPGoogleAdsTypes",
            ],
            path: "Sources/Adapters/MSPGoogleAdapter/MSPGoogleAdapter"
        ),
        
        /// MSPFacebookAdapter - Meta Audience Network adapter
        /// Dependencies: MSPSharedLibraries, MSPiOSCore, FBAudienceNetwork
        .target(
            name: "MSPFacebookAdapter",
            dependencies: [
                "MSPSharedLibraries",
                "MSPiOSCore",
                "FBAudienceNetwork",
            ],
            path: "Sources/Adapters/MSPFacebookAdapter/MSPFacebookAdapter"
        ),
        
        /// NovaAdapter - Nova custom ad format adapter
        /// Dependencies: MSPSharedLibraries, MSPiOSCore, NovaCoreLinker, MSPOMSDK, Kingfisher, SnapKit
        /// Uses NovaCoreLinker to ensure Lottie is linked with NovaCore
        .target(
            name: "NovaAdapter",
            dependencies: [
                "MSPSharedLibraries",
                "MSPiOSCore",
                "NovaCoreLinker",
                .product(name: "Kingfisher", package: "Kingfisher"),
                .product(name: "SnapKit", package: "SnapKit"),
            ],
            path: "Sources/Adapters/NovaAdapter/NovaAdapter"
        ),
        
        /// AmazonAdapter - Amazon Publisher Services adapter
        /// Dependencies: MSPSharedLibraries, MSPiOSCore, MSPGoogleAdsTypes, AmazonPublisherServicesSDK
        .target(
            name: "AmazonAdapter",
            dependencies: [
                "MSPSharedLibraries",
                "MSPiOSCore",
                "MSPGoogleAdsTypes",
                "AmazonPublisherServicesSDK",
            ],
            path: "Sources/Adapters/AmazonAdapter/AmazonAdapter"
        ),
        
        /// UnityAdapter - Unity Ads / IronSource adapter
        /// Dependencies: MSPSharedLibraries, MSPiOSCore, IronSourceSDK
        .target(
            name: "UnityAdapter",
            dependencies: [
                "MSPSharedLibraries",
                "MSPiOSCore",
                "IronSourceSDK",
            ],
            path: "Sources/Adapters/UnityAdapter/UnityAdapter"
        ),
        
        /// InmobiAdapter - InMobi advertising adapter
        /// Dependencies: MSPSharedLibraries, MSPiOSCore, InMobiSDK
        .target(
            name: "InmobiAdapter",
            dependencies: [
                "MSPSharedLibraries",
                "MSPiOSCore",
                "InMobiSDK",
            ],
            path: "Sources/Adapters/InmobiAdapter/InmobiAdapter"
        ),
        
        /// MobilefuseAdapter - MobileFuse advertising adapter
        /// Dependencies: MSPSharedLibraries, MSPiOSCore, MobileFuseSDK
        .target(
            name: "MobilefuseAdapter",
            dependencies: [
                "MSPSharedLibraries",
                "MSPiOSCore",
                "MobileFuseSDK",
            ],
            path: "Sources/Adapters/MobilefuseAdapter/MobilefuseAdapter"
        ),
        
        /// MintegralAdapter - Mintegral advertising adapter
        /// Dependencies: MSPSharedLibraries, MSPiOSCore, MTGSDK, MTGSDKBidding, MTGSDKBanner, MTGSDKNewInterstitial, MTGSDKInterstitialVideo
        .target(
            name: "MintegralAdapter",
            dependencies: [
                "MSPSharedLibraries",
                "MSPiOSCore",
                "MTGSDK",
                "MTGSDKBidding",
                "MTGSDKBanner",
                "MTGSDKNewInterstitial",
                "MTGSDKInterstitialVideo",
            ],
            path: "Sources/Adapters/MintegralAdapter/MintegralAdapter"
        ),
        
        /// PubmaticAdapter - PubMatic OpenWrap adapter
        /// Dependencies: MSPSharedLibraries, MSPiOSCore, OpenWrapSDK
        .target(
            name: "PubmaticAdapter",
            dependencies: [
                "MSPSharedLibraries",
                "MSPiOSCore",
                "OpenWrapSDK",
            ],
            path: "Sources/Adapters/PubmaticAdapter/PubmaticAdapter"
        ),
    ]
)
