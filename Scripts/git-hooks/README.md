# Git Hooks

This directory contains Git hooks for automatically formatting Swift code.

**Note**: This project now uses [Husky](https://github.com/typicode/husky) to manage Git hooks. The hooks are stored in `.husky/` directory and are automatically installed when you run `npm install`. See the [Husky Installation](#husky-installation-recommended) section below for details.

## Husky Installation (Recommended)

This project uses [Husky v9](https://github.com/typicode/husky) to automatically manage Git hooks. Hooks are stored in the `.husky/` directory and are automatically installed when you run `npm install`.

### Prerequisites

- **Node.js 14+** and **npm 6+** are required
- Install Node.js from [nodejs.org](https://nodejs.org/) or via Homebrew: `brew install node`

### Automatic Installation

After cloning the repository, simply run:

```bash
npm install
```

This will:
1. Install Husky as a dev dependency
2. Automatically run the `prepare` script
3. Set up Git hooks in `.husky/` directory
4. Configure Git's `core.hooksPath` to use `.husky`

### Verification

After installation, verify hooks are set up correctly:

```bash
# Check Git hooks path
git config core.hooksPath  # Should display: .husky

# Check hook exists
ls .husky/pre-commit  # Should exist and be executable
```

### Manual Husky Setup (if needed)

If for some reason hooks are not automatically installed, you can manually run:

```bash
npx husky install
```

## Legacy Installation Methods

The following methods are still available but **not recommended** for new setups:

### Manual Copy (No Node.js)

If you cannot install Node.js / Husky, you can manually copy the hook:

```bash
cp Scripts/git-hooks/pre-commit .git/hooks/pre-commit
chmod +x .git/hooks/pre-commit
```

**Note**: The hooks in `Scripts/git-hooks/` are kept for reference. The active hooks are in `.husky/` directory.

**Important**: If you have old hooks in `.git/hooks/` directory, they are no longer used (since `core.hooksPath` is set to `.husky`). You can safely remove them to avoid confusion.

## Pre-commit Hook

The `pre-commit` hook automatically formats staged Swift files before each commit.

### Features

- Automatically detects staged Swift files
- Uses `swift-format` to format code
- Automatically re-stages formatted files
- Skips files in Pods, build directories, generated files, etc.
- Uses centralized exclusion rules from `swift-format-exclusions.txt`

### Requirements

The hook will automatically detect `swift-format` in the following locations (in order):

1. System PATH (if installed via Homebrew or manually)
2. Xcode's toolchain: `/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/swift-format`
3. Xcode Command Line Tools: `/Library/Developer/CommandLineTools/usr/bin/swift-format`
4. DEVELOPER_DIR environment variable (for CI environments)

If `swift-format` is not found, the hook will skip formatting (with a warning) and allow the commit to proceed.

### Installing swift-format

If you need to install `swift-format` manually:

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

### Disabling the Hook

To temporarily disable the hook (not recommended):

```bash
git commit --no-verify
```

## Batch Formatting

To format all Swift files in the project at once (not just staged files), use the batch formatting script:

```bash
./Scripts/tools/format-all-swift.sh
```

This is useful for:
- Initial project setup
- After updating formatting rules
- Before major commits or releases

The script will format all Swift files and provide a detailed summary with statistics.

## Configuration

Formatting rules are configured in `.swift-format` and `swift-format.json` files in the project root.

File exclusion patterns are centralized in `swift-format-exclusions.txt` in the project root.

## Adding New Git Hooks

To add a new Git hook using Husky, use the `npx husky add` command:

```bash
# Add a pre-push hook
npx husky add .husky/pre-push "echo 'Running pre-push checks...'"

# Add a commit-msg hook
npx husky add .husky/commit-msg "echo 'Validating commit message...'"

# Add a post-commit hook
npx husky add .husky/post-commit "echo 'Post-commit tasks...'"
```

**Important**: All hooks should be added to `.husky/` directory, not `.git/hooks/`. This ensures they are:
- Version controlled (committed to the repository)
- Automatically installed for all team members
- Managed consistently through Husky

### Hook File Format

Each hook file in `.husky/` should follow this format:

```bash
#!/bin/sh
# Your hook commands here
```

**Note**: In Husky v9+, you no longer need to source `husky.sh`. The hook file should contain your script directly. The `husky.sh` file is deprecated and will be removed in Husky v10.

## Troubleshooting

### Hooks not working after npm install

1. Verify Node.js and npm are installed: `node --version` and `npm --version`
2. Run `npx husky install` manually
3. Check `git config core.hooksPath` shows `.husky`
4. Verify `.husky/pre-commit` exists and is executable
5. If `git config core.hooksPath` is empty, run `npm install` (recommended) or `npx husky install`

### If you don't have Node.js

If you cannot install Node.js / Husky, you can use the legacy hook by copying it into `.git/hooks/`:

```bash
# Make sure Git uses the default hooks directory
git config --unset core.hooksPath

cp Scripts/git-hooks/pre-commit .git/hooks/pre-commit
chmod +x .git/hooks/pre-commit
```
