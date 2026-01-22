# Swift Code Formatting Setup

This project has been configured for automatic Swift code formatting, following the [swift-nio formatting configuration](https://github.com/apple/swift-nio/commit/c9756e108351a1def2e2c83ff5ee6fb9bcbc3bbf).

## 📋 Completed Configuration

### 1. Formatting Configuration Files

- **`.swift-format`**: Main configuration file for swift-format tool
- **`swift-format.json`**: Detailed formatting rules configuration, including:
  - Line length limit: 120 characters
  - Indentation: 4 spaces
  - Various code style rules (referencing swift-nio's configuration)

### 2. CI/CD Integration

#### GitHub Actions (`.github/workflows/ci.yml`)

- Added `Setup Swift Format` step: Automatically installs swift-format
- Added `Check Swift Format` step: Checks formatting of all Swift files
- If formatting issues are found, CI will fail and display a list of files that need formatting

#### Jenkins (`Jenkinsfile`)

- Added `Swift Format Check` stage
- Automatically installs swift-format (if not installed)
- Checks formatting of all Swift files
- Excludes Pods, build directories, etc.

### 3. Git Pre-commit Hook

- **`.husky/pre-commit`**: Automatically formats staged Swift files (managed by Husky)
- **`Scripts/git-hooks/pre-commit`**: Legacy hook file (kept for reference)
- **Legacy (no Node.js)**: Copy `Scripts/git-hooks/pre-commit` into `.git/hooks/pre-commit`

### 4. Batch Formatting Script

- **`Scripts/tools/format-all-swift.sh`**: Script to format all Swift files in the project at once
  - Automatically detects swift-format (including Xcode's built-in version)
  - Excludes Pods, build directories, and other generated files
  - Preserves file header comments (moves imports back after headers)
  - Provides detailed summary and statistics
  - Shows next steps for reviewing and committing changes

- **`Scripts/lib/preserve-file-header.sh`**: Helper script to preserve file header comments
  - Automatically called by the formatting script
  - Ensures import statements stay after file header comments
  - Handles cases where swift-format moves imports before headers

## 🚀 Usage

### Installing Git Hooks

**Option 1: Husky Installation (Recommended)**

This project uses [Husky](https://github.com/typicode/husky) to automatically manage Git hooks. After cloning the repository, simply run:

```bash
npm install
```

This will automatically:
- Install Husky as a dev dependency
- Set up Git hooks in `.husky/` directory
- Configure Git's `core.hooksPath` to use `.husky`

**Prerequisites**: Node.js 14+ and npm 6+ are required. Install from [nodejs.org](https://nodejs.org/) or via Homebrew: `brew install node`

**Verification**:
```bash
git config core.hooksPath  # Should display: .husky
ls .husky/pre-commit        # Should exist and be executable
```

**Option 2: Legacy Manual Installation**

If you cannot install Node.js / Husky, you can install the legacy hook manually:

```bash
# Make sure Git uses the default hooks directory
git config --unset core.hooksPath

cp Scripts/git-hooks/pre-commit .git/hooks/pre-commit
chmod +x .git/hooks/pre-commit
```

After installation, staged Swift files will be automatically formatted on each commit.

### Formatting All Files

To format all Swift files in the project at once:

```bash
./Scripts/tools/format-all-swift.sh
```

This script will:
- Automatically detect `swift-format` (including Xcode's built-in version)
- Find all Swift files (excluding Pods, build directories, etc.)
- Format all files according to the configuration
- Display a detailed summary with statistics

**Non-interactive mode** (for CI or automated scripts):

```bash
CI=true ./Scripts/tools/format-all-swift.sh
```

### Manual File Formatting

For formatting individual files:

```bash
# Format a single file
swift-format -i --configuration swift-format.json <file>

# Format multiple files
swift-format -i --configuration swift-format.json file1.swift file2.swift

# Check formatting (without modifying files)
swift-format lint --configuration swift-format.json <file>
```

### Installing swift-format

The hook will automatically detect `swift-format` in the following locations (in order):

1. System PATH (if installed via Homebrew or manually)
2. Xcode's toolchain: `/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/swift-format`
3. Command Line Tools: `/Library/Developer/CommandLineTools/usr/bin/swift-format`

If `swift-format` is not found, you can install it manually:

**Option 1: Build from source**

```bash
git clone https://github.com/apple/swift-format.git
cd swift-format
swift build -c release
sudo cp .build/release/swift-format /usr/local/bin/swift-format
```

**Option 2: Using Xcode's toolchain** (if available)

```bash
# Create a symlink if Xcode has swift-format
sudo ln -s /Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/swift-format /usr/local/bin/swift-format
```

## 📝 Formatting Rules

Main rules include:

- **Line Length**: 120 characters
- **Indentation**: 4 spaces
- **Import Sorting**: Automatically sorts import statements
- **Trailing Closures**: Uses simplified trailing closure syntax
- **Return Statements**: Omits explicit return (when possible)
- **Comments**: Uses `///` for documentation comments
- **Code Blocks**: No block comments (`/* */`)
- **No Empty Lines in Braces**: Removes empty lines immediately after opening braces and before closing braces (e.g., method definitions won't have blank lines after `{`)

See the `swift-format.json` file for the complete list of rules.

## 🔍 CI Checks

Formatting checks run in CI under the following conditions:

1. **GitHub Actions**: On every PR and push
2. **Jenkins**: On every build

If formatting issues are found, CI will fail and display a list of files that need to be fixed.

## 📊 Formatting Script Output

The `format-all-swift.sh` script provides detailed output:

- **Total files scanned**: Number of Swift files found in the project
- **Files formatted**: Number of files that were formatted
- **Already formatted**: Number of files that were already properly formatted
- **Files changed**: Number of files that were actually modified (if in git repo)
- **Code Statistics**: Git diff statistics showing insertions and deletions
- **Next steps**: Helpful commands for reviewing and committing changes

Example output:
```
✅ Formatting Summary
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
   Total files scanned:     684
   Files formatted:         390
   Already formatted:       294
   Files changed:           268
   Errors:                  0

📊 Code Statistics:
   270 files changed, 6703 insertions(+), 4659 deletions(-)

💡 Next steps:
   1. Review changes:     git diff
   2. Review specific file: git diff <file>
   3. Stage all changes:   git add .
   4. Commit changes:      git commit -m "chore: format Swift files"
```

## ⚠️ Notes

1. **Excluded Files and Directories**: The following are automatically excluded from formatting:
   - `*.pb.swift` - Protocol Buffers generated files
   - `Pods/` - CocoaPods dependencies
   - `.build/` - Swift Package Manager build artifacts (at any level)
   - `build/` - Build output directories
   - `DerivedData/` - Xcode derived data
   - `output*/` - Output directories
   - `xcframework/` - XCFramework directories
   - `.swiftpm/` - Swift Package Manager metadata
   - `xcuserdata/` and `xcshareddata/` - Xcode user data
2. **Temporary Disable**: You can use `git commit --no-verify` to temporarily skip the hook (not recommended)
3. **Git Hooks Configuration**: This project uses Husky to manage Git hooks. After cloning, run `npm install` to automatically set up hooks. The hooks are stored in `.husky/` directory and are committed to the repository. If you don't have Node.js, you can manually copy `Scripts/git-hooks/pre-commit` into `.git/hooks/pre-commit` (and unset `core.hooksPath` if needed).
4. **Batch Formatting**: The `format-all-swift.sh` script is idempotent - running it multiple times is safe and will only format files that need formatting.
5. **File Header Preservation**: The formatting script automatically preserves file header comments (like Xcode-generated file headers). Import statements will be kept after file headers, not before them.

## 📚 References

- [swift-format Documentation](https://github.com/apple/swift-format)
- [swift-nio Formatting Configuration](https://github.com/apple/swift-nio/commit/c9756e108351a1def2e2c83ff5ee6fb9bcbc3bbf)
