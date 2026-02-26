#!/usr/bin/env ruby
# -*- coding: utf-8 -*-
# Generate core-only Package.swift for spm-release mode
#
# Keeps:    Core binary targets (MSPSharedLibraries, MSPiOSCore, MSPCore, NovaCore)
#           Published adapters (MSPPrebidAdapter, MSPGoogleAdapter, MSPFacebookAdapter,
#                              MSPNovaAdapter, MSPAmazonAdapter, MSPMolocoAdapter, MSPLiftoffAdapter)
#           Linker targets (MSPCoreLinker, NovaCoreLinker)
#           SPM-native dependencies (Kingfisher, SwiftProtobuf, Lottie)
#           Available third-party binary targets (PrebidMobile, MSPSnapKit)
#
# Removes:  Unpublished adapters (Unity, Inmobi, Mobilefuse, Mintegral, Pubmatic)
#           Pods-only third-party binary targets (FBAudienceNetwork, IronSourceSDK, etc.)
#           Pods-only source targets (MSPGoogleAdsTypes, Shimmer)
#           Google Mobile Ads SPM dependency
#
# Strips:   Pods-only dependencies from published adapter targets

template_path = ARGV[0]
output_path = ARGV[1]

content = File.read(template_path, encoding: 'utf-8')

# ============================================================================
# Configuration
# ============================================================================

# Third-party binary targets to remove (Pods-only, no local XCFrameworks)
THIRDPARTY_BINARY_TARGETS = %w[
  FBAudienceNetwork IronSourceSDK InMobiSDK MobileFuseSDK
  MTGSDK MTGSDKBidding MTGSDKBanner MTGSDKNewInterstitial MTGSDKInterstitialVideo
  OpenWrapSDK AmazonPublisherServicesSDK MolocoSDKiOS VungleAds
]

# Unpublished adapter names (products + targets removed entirely)
UNPUBLISHED_ADAPTERS = %w[
  UnityAdapter InmobiAdapter MobilefuseAdapter MintegralAdapter PubmaticAdapter
]

# Source targets to remove (depend on Pods-only external packages)
REMOVE_SOURCE_TARGETS = %w[MSPGoogleAdsTypes Shimmer]

# Dependencies to strip globally from any target's dependency list
# These reference binary targets or source targets being removed
STRIP_DEPS = %w[
  FBAudienceNetwork MSPGoogleAdsTypes AmazonPublisherServicesSDK
  MolocoSDKiOS VungleAds
]

# ============================================================================
# Step 1: Remove unpublished adapter product lines
# ============================================================================
UNPUBLISHED_ADAPTERS.each do |adapter|
  content.gsub!(/^        \.library\(name: "#{adapter}", targets: \["#{adapter}"\]\),\n/, '')
end

# ============================================================================
# Step 2: Remove Google Mobile Ads SPM dependency
# ============================================================================
# Pattern: comment line + .package( block + trailing blank line
content.gsub!(
  /^        \/\/ Google Mobile Ads SDK[^\n]*\n        \.package\(\n            url: "[^"]*google-mobile-ads[^"]*",\n            from: "[^"]*"\n        \),\n        \n/,
  '')

# ============================================================================
# Step 3: Remove third-party binary targets by name (path-agnostic)
# ============================================================================
# Uses name-based matching so path changes in template don't break removal
THIRDPARTY_BINARY_TARGETS.each do |name|
  # Match: optional /// comment lines + .binaryTarget(name: "X", path: "..."), + optional blank line
  content.gsub!(
    /(?:^        \/\/\/[^\n]*\n)*^        \.binaryTarget\(\n            name: "#{Regexp.escape(name)}",\n            path: "[^"]*"\n        \),\n(?:        \n)?/,
    ''
  )
end

# ============================================================================
# Step 4: Remove Pods-only source targets (MSPGoogleAdsTypes, Shimmer)
# ============================================================================
REMOVE_SOURCE_TARGETS.each do |name|
  # Match: optional /// comments + .target(name: "X", ...) block + optional blank line
  # /m makes . match newlines for the lazy inner match
  content.gsub!(
    /(?:^        \/\/\/[^\n]*\n)*^        \.target\(\n            name: "#{Regexp.escape(name)}",.*?\n        \),\n(?:        \n)?/m,
    ''
  )
end

# ============================================================================
# Step 5: Remove unpublished adapter targets
# ============================================================================
UNPUBLISHED_ADAPTERS.each do |name|
  content.gsub!(
    /(?:^        \/\/\/[^\n]*\n)*^        \.target\(\n            name: "#{Regexp.escape(name)}",.*?\n        \),\n(?:        \n)?/m,
    ''
  )
end

# ============================================================================
# Step 6: Strip removed dependencies from published adapter targets
# ============================================================================
STRIP_DEPS.each do |dep|
  # Remove dependency line: 16 spaces + "DepName", + newline
  content.gsub!(/^                "#{Regexp.escape(dep)}",\n/, '')
end

# ============================================================================
# Step 7: Remove Shimmer from NovaCoreLinker
# ============================================================================
content.gsub!('ensures Lottie and Shimmer are linked with NovaCore',
             'ensures Lottie is linked with NovaCore')
content.gsub!('undefined Lottie/Shimmer symbols',
             'undefined Lottie symbols')
content.gsub!(/^                "Shimmer",\n/, '')

# ============================================================================
# Step 8: Update comment counts
# ============================================================================
published_count = 12 - UNPUBLISHED_ADAPTERS.size
content.gsub!(/Adapter Module Products \(\d+\)/, "Adapter Module Products (#{published_count})")

# Write filtered content
File.write(output_path, content)
