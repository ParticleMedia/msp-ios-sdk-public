#!/usr/bin/env bash
# ============================================================================
# Distribution Utilities Module
# ============================================================================
# Module: distribution_utils.sh
# Purpose: Pod distribution type checking and module listing utilities
# Extracted from: publish.sh
#
# Functions:
#   - is_binary_distribution: Check if pod uses binary distribution
#   - get_default_pods_modules: Get default list of pods to release
#   - get_adapters_list: Get list of adapter pods
#
# Dependencies:
#   - None (standalone utility module)
#
# Usage:
#   source distribution_utils.sh
#   if is_binary_distribution "MSPCore"; then
#       echo "MSPCore is a binary distribution pod"
#   fi
# ============================================================================

set -euo pipefail

# Guard against multiple sourcing
[[ -n "${_DISTRIBUTION_UTILS_SOURCED:-}" ]] && return 0
readonly _DISTRIBUTION_UTILS_SOURCED=1

# ============================================================================
# Binary Distribution Check
# ============================================================================
# Check if a pod uses binary distribution (HTTP zip source from GitHub Releases).
# This is a DISTRIBUTION METHOD check, NOT a release order check.
#
# Binary Distribution Pods:
# - MSPiOSCore: Foundation framework (binary only)
# - MSPSharedLibraries: Contains multiple XCFrameworks + PrebidMobile
# - MSPCore: Main framework (binary distribution)
# - MSPNovaAdapter: Includes private NovaCore.xcframework (binary only)
# - All adapters: Now use binary distribution
#
# Note: Must match BINARY_DISTRIBUTION_PODS in generate_podspec.sh
# ============================================================================
is_binary_distribution() {
    local pod="$1"
    case "$pod" in
        MSPiOSCore|MSPSharedLibraries|MSPGoogleAdsTypes|MSPCore|MSPNovaAdapter|MSPPrebidAdapter|MSPGoogleAdapter|MSPFacebookAdapter|MSPAmazonAdapter|MSPMolocoAdapter|MSPLiftoffAdapter)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

# ============================================================================
# Default Pods Modules List
# ============================================================================
# Returns the default list of pods to release in correct dependency order.
#
# Release order: MSPiOSCore → MSPSharedLibraries → MSPGoogleAdsTypes → Adapters → MSPCore
# ============================================================================
get_default_pods_modules() {
    echo "MSPiOSCore MSPSharedLibraries MSPGoogleAdsTypes MSPPrebidAdapter MSPCore MSPGoogleAdapter MSPFacebookAdapter MSPNovaAdapter MSPAmazonAdapter MSPMolocoAdapter MSPLiftoffAdapter"
}

# ============================================================================
# Adapters List
# ============================================================================
# Returns the list of adapter pods.
# ============================================================================
get_adapters_list() {
    echo "MSPPrebidAdapter MSPGoogleAdapter MSPFacebookAdapter MSPNovaAdapter MSPAmazonAdapter MSPMolocoAdapter MSPLiftoffAdapter"
}

# ============================================================================
# Core Pods List
# ============================================================================
# Returns the list of core (non-adapter) pods.
# ============================================================================
get_core_pods_list() {
    echo "MSPiOSCore MSPSharedLibraries MSPGoogleAdsTypes MSPCore"
}

# ============================================================================
# Binary Distribution Pods List
# ============================================================================
# Returns the list of pods that use binary distribution.
# ============================================================================
get_binary_distribution_pods() {
    echo "MSPiOSCore MSPSharedLibraries MSPGoogleAdsTypes MSPCore MSPNovaAdapter MSPPrebidAdapter MSPGoogleAdapter MSPFacebookAdapter MSPAmazonAdapter MSPMolocoAdapter MSPLiftoffAdapter"
}

# ============================================================================
# Export Functions
# ============================================================================

export -f is_binary_distribution 2>/dev/null || true
export -f get_default_pods_modules 2>/dev/null || true
export -f get_adapters_list 2>/dev/null || true
export -f get_core_pods_list 2>/dev/null || true
export -f get_binary_distribution_pods 2>/dev/null || true
