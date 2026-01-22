# Swift Format Integration - Team Announcement

## Overview

We've integrated swift-format into the MSP iOS SDK project to ensure consistent code formatting across our Swift codebase. This will help maintain code readability and reduce formatting-related discussions during code reviews.

## What You Need to Do

### 1. Install Husky Hooks (One-time Setup)

After pulling the latest changes from main, run:

```bash
npm install
```

This activates the pre-commit hooks that will automatically format your Swift files before committing.

### 2. Install swift-format (if needed)

The pre-commit hook will automatically install swift-format if it's not present. You can also manually install it:

```bash
brew install swift-format
```

## How It Works

### Automatic Formatting

When you commit Swift files, the pre-commit hook will:
1. Detect staged Swift files
2. Format them using our project's swift-format rules
3. Re-stage the formatted files
4. Continue with the commit

### Manual Formatting

To format all Swift files in the project:

```bash
./Scripts/tools/format-all-swift.sh
```

To format a specific file:

```bash
swift-format format path/to/file.swift --configuration swift-format.json --in-place
```

## CI Integration

Jenkins will check that all Swift files are properly formatted in the consistency check stage. If formatting issues are found, the build will fail with instructions on how to fix them.

## Configuration

Our formatting rules are based on the swift-nio project standards with some adjustments:
- Maximum line length: 140 characters
- Tab width: 4 spaces
- Function/Type naming preserved for SDK public APIs

## Exclusions

The following are excluded from formatting:
- `.build/` directory
- `ThirdParty/` directory  
- Generated files (`*.generated.swift`)
- Files with `@swift-format-disable` comment

## Troubleshooting

### Hook Not Running

If the pre-commit hook isn't running:

```bash
# Check if hooks are installed
git config core.hooksPath

# If empty, reinstall
npm install
```

### Format Check Failures

If you see formatting errors:

```bash
# Fix all formatting issues
./Scripts/tools/format-all-swift.sh

# Stage and commit the changes
git add -u
git commit -m "style: apply swift-format"
```

### Syntax Errors

If swift-format reports syntax errors:
1. Fix the syntax error in your code
2. Run the formatter again
3. If the error persists, add the file to exclusions temporarily

## Questions?

If you have questions or encounter issues:
1. Check `SWIFT_FORMAT_SETUP.md` for detailed documentation
2. Review the swift-format configuration in `swift-format.json`
3. Ask in #ios-sdk-dev channel

## Benefits

- ✅ Consistent code style across the entire codebase
- ✅ Automated formatting reduces manual work
- ✅ Fewer formatting discussions in code reviews
- ✅ Better code readability and maintainability

Thank you for helping maintain code quality in the MSP iOS SDK! 🎉
