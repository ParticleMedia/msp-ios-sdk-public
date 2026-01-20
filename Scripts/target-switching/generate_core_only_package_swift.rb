#!/usr/bin/env ruby
# -*- coding: utf-8 -*-
# Generate published-units-only Package.swift for spm-release mode
# Includes ONLY: MSPSharedLibraries, MSPCore, MSPFacebookAdapter, MSPGoogleAdapter, MSPNovaAdapter, MSPAmazonAdapter, MSPPrebidAdapter
# Excludes: All Pods-only third-party SDKs (FBAudienceNetwork, IronSourceSDK, etc.)
# Adapters are included but their third-party SDK dependencies are removed

template_path = ARGV[0]
output_path = ARGV[1]

content = File.read(template_path, encoding: 'utf-8')

# Published adapter products (keep these)
published_adapters = %w[
  MSPPrebidAdapter MSPGoogleAdapter MSPFacebookAdapter MSPNovaAdapter MSPAmazonAdapter
]

# Unpublished adapter products (remove these)
unpublished_adapters = %w[
  UnityAdapter InmobiAdapter MobilefuseAdapter MintegralAdapter PubmaticAdapter
]

# Remove unpublished adapter products
unpublished_adapters.each do |adapter|
  content.gsub!(/        \.library\(name: "#{adapter}", targets: \["#{adapter}"\]\),\n/, '')
end

# Update adapter products comment
content.gsub!(/        \/\/ Adapter Module Products \(10\) - Swift Source Targets/, 
             '        // Adapter Module Products (5 published) - Swift Source Targets')

# Remove Google Mobile Ads SDK dependency (Pods-only, not exposed to SPM)
content.gsub!(/        \/\/ Google Mobile Ads SDK - Required by MSPGoogleAdapter, AmazonAdapter\n        \.package\(\n            url: "https:\/\/github\.com\/googleads\/swift-package-manager-google-mobile-ads\.git",\n            from: "11\.0\.0"\n        \),\n        \n/, '')

# Remove ALL Pods-only third-party SDK binary targets (not exposed to SPM)
# FBAudienceNetwork
content.gsub!(/        \/\/\/ FBAudienceNetwork - Meta Audience Network SDK\n        \/\/\/ Used by: MSPFacebookAdapter\n        \.binaryTarget\(\n            name: "FBAudienceNetwork",\n            path: "ThirdParty\/FBAudienceNetwork\/FBAudienceNetwork\.xcframework"\n        \),\n        \n/, '')

# IronSourceSDK
content.gsub!(/        \/\/\/ IronSourceSDK - Unity LevelPlay \/ IronSource SDK\n        \/\/\/ Used by: UnityAdapter\n        \.binaryTarget\(\n            name: "IronSourceSDK",\n            path: "ThirdParty\/IronSourceSDK\/IronSourceSDK\.xcframework"\n        \),\n        \n/, '')

# InMobiSDK
content.gsub!(/        \/\/\/ InMobiSDK - InMobi advertising SDK\n        \/\/\/ Used by: InmobiAdapter\n        \.binaryTarget\(\n            name: "InMobiSDK",\n            path: "ThirdParty\/InMobiSDK\/InMobiSDK\.xcframework"\n        \),\n        \n/, '')

# MobileFuseSDK
content.gsub!(/        \/\/\/ MobileFuseSDK - MobileFuse advertising SDK\n        \/\/\/ Used by: MobilefuseAdapter\n        \.binaryTarget\(\n            name: "MobileFuseSDK",\n            path: "ThirdParty\/MobileFuseSDK\/MobileFuseSDK\.xcframework"\n        \),\n        \n/, '')

# Mintegral SDK (all 5 targets)
content.gsub!(/        \/\/\/ Mintegral SDK - Multi-module advertising SDK\n        \/\/\/ Used by: MintegralAdapter\n        \/\/\/ Subspecs: MTGSDK \(core\), MTGSDKBidding, MTGSDKBanner, MTGSDKNewInterstitial\n        \.binaryTarget\(\n            name: "MTGSDK",\n            path: "ThirdParty\/MintegralAdSDK\/MTGSDK\.xcframework"\n        \),\n        \.binaryTarget\(\n            name: "MTGSDKBidding",\n            path: "ThirdParty\/MintegralAdSDK\/MTGSDKBidding\.xcframework"\n        \),\n        \.binaryTarget\(\n            name: "MTGSDKBanner",\n            path: "ThirdParty\/MintegralAdSDK\/MTGSDKBanner\.xcframework"\n        \),\n        \.binaryTarget\(\n            name: "MTGSDKNewInterstitial",\n            path: "ThirdParty\/MintegralAdSDK\/MTGSDKNewInterstitial\.xcframework"\n        \),\n        \.binaryTarget\(\n            name: "MTGSDKInterstitialVideo",\n            path: "ThirdParty\/MintegralAdSDK\/MTGSDKInterstitialVideo\.xcframework"\n        \),\n        \n/m, '')

# OpenWrapSDK
content.gsub!(/        \/\/\/ OpenWrapSDK - PubMatic OpenWrap SDK\n        \/\/\/ Used by: PubmaticAdapter\n        \.binaryTarget\(\n            name: "OpenWrapSDK",\n            path: "ThirdParty\/OpenWrapSDK\/OpenWrapSDK\.xcframework"\n        \),\n        \n/, '')

# AmazonPublisherServicesSDK
content.gsub!(/        \/\/\/ AmazonPublisherServicesSDK - Amazon APS SDK\n        \/\/\/ Used by: MSPAmazonAdapter\n        \.binaryTarget\(\n            name: "AmazonPublisherServicesSDK",\n            path: "ThirdParty\/AmazonPublisherServicesSDK\/AmazonPublisherServicesSDK\.xcframework"\n        \),\n        \n/, '')

# Remove MSPGoogleAdsTypes target (depends on Google Mobile Ads SDK which is Pods-only)
content.gsub!(/        \/\/\/ MSPGoogleAdsTypes - Abstraction layer for GoogleMobileAds SDK\n        \/\/\/ Provides unified API across CocoaPods and SPM builds\n        \/\/\/ Used by: MSPGoogleAdapter, MSPAmazonAdapter\n        \.target\(\n            name: "MSPGoogleAdsTypes",\n            dependencies: \[\n                \.product\(name: "GoogleMobileAds", package: "swift-package-manager-google-mobile-ads"\),\n            \],\n            path: "Sources\/Common\/MSPGoogleAdsTypes"\n        \),\n        \n/m, '')

# Remove unpublished adapter targets
unpublished_adapter_targets = [
  ['UnityAdapter', 'UnityAdapter', 'UnityAdapter'],
  ['InmobiAdapter', 'InmobiAdapter', 'InmobiAdapter'],
  ['MobilefuseAdapter', 'MobilefuseAdapter', 'MobilefuseAdapter'],
  ['MintegralAdapter', 'MintegralAdapter', 'MintegralAdapter'],
  ['PubmaticAdapter', 'PubmaticAdapter', 'PubmaticAdapter']
]

unpublished_adapter_targets.each do |comment_name, target_name, path_name|
  # Pattern matches target definition followed by either:
  # 1. Empty line + indentation (middle of targets array): \n        \n
  # 2. End of targets array (last element before ]): directly before \n    ]
  # Note: Comments may span multiple lines (/// name and /// Dependencies)
  pattern = /        \/\/\/ #{comment_name}[^\n]*\n(?:        \/\/\/[^\n]*\n)*        \.target\(\n            name: "#{target_name}",\n            dependencies: \[[^\]]*\],\n            path: "Sources\/Adapters\/#{path_name}\/#{path_name}"\n        \),\n(?:        \n|(?=    \]))/m
  content.gsub!(pattern, '')
end

# Modify published adapter targets to remove Pods-only third-party SDK dependencies
# MSPFacebookAdapter: Remove FBAudienceNetwork dependency
content.gsub!(/(        \.target\(\n            name: "MSPFacebookAdapter",\n            dependencies: \[\n                "MSPSharedLibraries",\n                "MSPiOSCore",\n                )"FBAudienceNetwork",(\n            \],)/m, 
             '\1\2')

# MSPGoogleAdapter: Remove MSPGoogleAdsTypes dependency (depends on Pods-only Google Mobile Ads)
content.gsub!(/(        \.target\(\n            name: "MSPGoogleAdapter",\n            dependencies: \[\n                "MSPSharedLibraries",\n                "MSPiOSCore",\n                )"MSPGoogleAdsTypes",(\n            \],)/m, 
             '\1\2')

# MSPAmazonAdapter: Remove MSPGoogleAdsTypes and AmazonPublisherServicesSDK dependencies
content.gsub!(/(        \.target\(\n            name: "MSPAmazonAdapter",\n            dependencies: \[\n                "MSPSharedLibraries",\n                "MSPiOSCore",\n                )"MSPGoogleAdsTypes",\n                "AmazonPublisherServicesSDK",(\n            \],)/m, 
             '\1\2')

# MSPPrebidAdapter: Keep PrebidMobile (it exists and is needed)
# No change needed - PrebidMobile is already included

# MSPNovaAdapter: Keep as-is (depends on NovaCoreLinker, MSPOMSDK, Kingfisher, SnapKit - all valid)
# No change needed

# Remove Shimmer target (removed from NovaCore)
content.gsub!(/        \/\/\/ Shimmer - Facebook shimmering effect library \(Objective-C\)\n        \/\/\/ Bundled from CocoaPods for SPM compatibility\n        \.target\(\n            name: "Shimmer",\n            dependencies: \[\],\n            path: "ThirdParty\/Shimmer\/Shimmer",\n            publicHeadersPath: "include"\n        \),\n        \n/m, '')

# Remove Shimmer from NovaCoreLinker dependencies and update comment
content.gsub!(/        \/\/\/ NovaCoreLinker - ensures Lottie and Shimmer are linked with NovaCore\n        \/\/\/ NovaCore\.xcframework has undefined Lottie\/Shimmer symbols that need runtime linking/, 
             '        /// NovaCoreLinker - ensures Lottie is linked with NovaCore\n        /// NovaCore.xcframework has undefined Lottie symbols that need runtime linking')

content.gsub!(/"Shimmer",\n                /, '')

# Write filtered content
File.write(output_path, content)

