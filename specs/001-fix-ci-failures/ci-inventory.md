# CI Inventory

## Workflows (.github/workflows)

- **ci-pull-request.yml**
  - Jobs: quick-validation, build-xcframeworks (matrix), build-demoapp (pods-dev/pods-release), consistency-check, ci-status
  - Scripts:
    - Scripts/validation/validate_assets.sh
    - Scripts/xcframeworks/build_module.sh
    - Scripts/spm-sync/generate_package_swift.sh
    - Scripts/validation/verify_pods_spm_consistency.sh
    - Scripts/workspace/update.sh
  - Paths referenced:
    - Build/XCFrameworks
    - Examples/MSPDemoApp (project)
    - msp-ios-sdk.xcworkspace (workspace)
    - Sources/Adapters/MSPGoogleAdapter
    - Sources/Adapters/*
  - Secrets/vars: none explicitly in this workflow

- **unit-tests.yml**
  - Jobs: test
  - Scripts: Scripts/tests/run-unit-tests.sh, Scripts/workspace/update.sh
  - Paths referenced:
    - msp-ios-sdk.xcworkspace
    - build/TestResults.xcresult
  - Secrets/vars: none
  - Tools: jq, bc (xcpretty optional)

- **asset-validation.yml**
  - Jobs: validate-assets, sync-assets
  - Scripts:
    - Scripts/lib/asset_sync.sh
    - Scripts/lib/asset_validation.sh
  - Paths referenced:
    - Sources/Core/NovaCore/NovaCore/NBAssets.xcassets
    - Sources/Core/NovaCore/NovaCore/NBResourceBundle.bundle
  - Secrets/vars: GITHUB_TOKEN (for PR comments)

- **manual-build.yml**
  - Jobs: build
  - Scripts/Tools: fastlane
  - Secrets:
    - CODE_SIGNING_P12
    - CODE_SIGNING_PASSWORD

- **release.yml**
  - Jobs: release
  - Scripts/Tools: fastlane, Scripts/lib/release-common.sh
  - Secrets:
    - CODE_SIGNING_P12
    - CODE_SIGNING_PASSWORD
    - COCOAPODS_TRUNK_TOKEN
    - SLACK_WEBHOOK_URL
  - Vars:
    - SLACK_CHANNEL

- **pr-labeler.yml**
  - Jobs: commit-label
  - Scripts: embedded github-script
  - Secrets/vars: none

## Jenkinsfiles (root)

- Jenkinsfile.cocoapods
- Jenkinsfile.consistency
- Jenkinsfile.demoapp
- Jenkinsfile.spm

## Key Scripts (root)

- setup_ci_cd.sh
- Scripts/ci/ci_validate.sh
- Scripts/tests/run-unit-tests.sh
