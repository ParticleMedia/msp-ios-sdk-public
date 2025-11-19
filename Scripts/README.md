# Scripts Overview

Automation in this repository is driven by Xcodegen + CocoaPods; no manual Xcode edits are allowed. All commands are deterministic and can be re-run locally or in CI.

## update-workspace.sh

```
./Scripts/workspace/update.sh
```

What it does:

1. Scans the repo for every `Package.swift`.
2. Rewrites `MSPDemoApp/project.yml`, `workspace.yml`, and `msp-ios-sdk.xcworkspace/xcshareddata/swiftpm/local-packages.json`.
3. Runs `xcodegen generate --spec workspace.yml` when Xcodegen ≥ 2.38 is installed.
4. If `CI=true`, runs `bundle exec pod install`; outside CI it prints a reminder because the Codex sandbox cannot modify the global CocoaPods cache.

Environment notes:

- Install Xcodegen via `brew install xcodegen`.
- Run `bundle exec pod install` on a macOS host or GitHub Actions runner after regenerating the specs.
- Generated `.xcodeproj`/`.xcworkspace` directories are ignored by git; always commit the YAML specs instead.

## Additional scripts

| Script | Purpose |
| ------ | ------- |
| `build.sh`, `buildDemoApp.sh`, etc. | Adapter and SDK build helpers (still valid; see inline `--help`). |
| `release-*.sh` | CocoaPods/SPM release orchestration. |
| `lib/*.sh` | Shared shell helpers used by CI and release scripts. |

All scripts assume that `./Scripts/workspace/update.sh` has been run and that the Pod install exists on disk. Use the same sequence locally before invoking Fastlane or the release tooling.
