# Changelog

All notable changes to the MSP iOS SDK will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

> **Note:** This changelog starts fresh. For the changelog entry format, see [Docs/CHANGELOG_TEMPLATE.yaml](Docs/CHANGELOG_TEMPLATE.yaml).

## [Unreleased]

### Fixed
- **MSPSnapKit symbol leak**: `unexported_symbols.txt` now uses correct `_$s10MSPSnapKit*` pattern (10-char module name) instead of only `_$s7SnapKit*` (7-char), fixing 564 leaked symbols from NovaCore.xcframework
- **OMSDK duplicate classes**: Rebuilt PrebidMobile.xcframework to dynamically link `OMSDK_Newsbreak1` instead of statically embedding `OMSDK-Static_Newsbreak1`, eliminating 38 duplicate `OMIDNewsbreak1*` ObjC class warnings. Moved OMSDK distribution from MSPNovaAdapter to MSPSharedLibraries for a single runtime copy.

### Removed
- **lottie-ios dependency**: Replaced Lottie-based tap-to-try animation with a pure UIView/CAAnimation implementation (`NovaAdTapToTryAnimationView`), removing 2,858 symbols and 151 ObjC classes from NovaCore to prevent duplicate class conflicts with host apps using Lottie
