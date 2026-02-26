---
id: ctx-sources-004
title: 脚本最佳实践 (AI-First)
layer: tech
domain: sources
tags: [bash, python, scripts, config-driven, posix, automation]
triggers: [script, bash, shell, python, sh, automation, config, yaml, set -euo, pipefail, subprocess]
summary: "Bash/Python 脚本硬规则与软规则，覆盖 config-driven 开发、POSIX 兼容、错误处理、原子写入、语言选择"
version: "2.0"
created: 2026-02-22
updated: 2026-02-22
source: manual
status: active
confidence: high
---

# 脚本最佳实践 (AI-First)

## Core Philosophy

```
YAML Configuration  -->  Script Logic  -->  Deterministic Output
(what to do)             (how to do it)     (reproducible result)
```

All automation reads from configuration files. Scripts never hardcode values that belong in config. Per Federal Constitution Article I.1, any manual operation repeated more than twice must be scripted. Per Scripts/constitution.md Article VI.1, scripts must fail fast and explicitly.

---

## Hard Rules (HR)

### HR-1: ALWAYS start bash scripts with `set -euo pipefail`

**Citation**: [Google Shell Style Guide](https://google.github.io/styleguide/shellguide.html); [Safer Bash Scripts](https://vaneyckt.io/posts/safer_bash_scripts_with_set_euxo_pipefail/); Constitution Article VI.1

```bash
# CORRECT: strict mode catches errors immediately
#!/usr/bin/env bash
set -euo pipefail

readonly CONFIG="release.yaml"
VERSION=$(yq eval '.version' "$CONFIG")
echo "Building version ${VERSION}"
```

```bash
# WRONG: silent failure — undefined variable expands to empty string,
# failed command is ignored, broken pipe goes unnoticed
#!/usr/bin/env bash

VERSION=$(yq eval '.version' "$MISSING_FILE")
echo "Building version ${VERSION}"
# Script continues even though VERSION is empty
```

---

### HR-2: NEVER hardcode paths or values — use config files (YAML)

**Citation**: [The Twelve-Factor App — Factor III: Config](https://12factor.net/config); Constitution Article I.3 (SSOT)

```bash
# WRONG: hardcoded path and version
FRAMEWORK_PATH="/Users/dev/build/MSPCore.xcframework"
VERSION="1.2.3"
```

```bash
# CORRECT (bash + yq): read from YAML config
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
readonly CONFIG="${PROJECT_ROOT}/Scripts/config/release.yaml"

VERSION=$(yq eval '.version' "$CONFIG")
FRAMEWORK_PATH="${PROJECT_ROOT}/Build/ReleaseArtifacts/XCFrameworks/MSPCore.xcframework"
```

```python
# CORRECT (python + pyyaml): read from YAML config
import yaml
from pathlib import Path

config_path = Path(__file__).resolve().parent.parent / "config" / "release.yaml"
with open(config_path) as f:
    config = yaml.safe_load(f)

version = config["version"]
```

---

### HR-3: ALWAYS use atomic file writes (temp file + mv/os.replace)

**Citation**: POSIX atomicity guarantees for `rename(2)`; [MIT SIPB Safe Shell Scripting](https://sipb.mit.edu/doc/safe-shell/)

```bash
# WRONG: partial write on failure leaves corrupted file
generate_content > "$TARGET_FILE"
```

```bash
# CORRECT (bash): temp file + mv ensures atomicity
TEMP_FILE=$(mktemp "${TMPDIR:-/tmp}/output.XXXXX")
trap 'rm -f "$TEMP_FILE"' EXIT

generate_content > "$TEMP_FILE"
mv "$TEMP_FILE" "$TARGET_FILE"
```

```python
# CORRECT (python): tempfile + os.replace ensures atomicity
import tempfile, os

with tempfile.NamedTemporaryFile(
    mode="w", dir=os.path.dirname(target), delete=False
) as tmp:
    tmp.write(content)
    tmp_path = tmp.name
os.replace(tmp_path, target)  # atomic on same filesystem
```

---

### HR-4: ALWAYS use `readonly` for constants and script directory variables

**Citation**: [Google Shell Style Guide](https://google.github.io/styleguide/shellguide.html); ShellCheck SC2155

Separate assignment from `readonly` to avoid masking return codes (SC2155).

```bash
# WRONG: readonly + command substitution masks exit code
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
```

```bash
# CORRECT: separate declare and readonly
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
readonly PROJECT_ROOT
```

---

### HR-5: NEVER parse YAML/JSON with regex — use proper parsers

**Citation**: [Stack Overflow canonical answer on regex vs structured data](https://stackoverflow.com/a/1732454); YAML 1.2 specification (multi-line, anchors, aliases)

```bash
# WRONG: fragile regex — breaks on comments, multi-line, quoting
VERSION=$(grep "version:" release.yaml | sed 's/version: //')
```

```bash
# CORRECT (bash): yq handles all YAML edge cases
VERSION=$(yq eval '.version' release.yaml)
ADAPTER_NAMES=$(yq eval '.adapters[].name' release.yaml)
```

```python
# WRONG: regex on YAML
import re
match = re.search(r"version:\s*(.+)", yaml_text)

# CORRECT (python): proper parser
import yaml
config = yaml.safe_load(yaml_text)
version = config["version"]
```

---

### HR-6: ALWAYS quote variables in bash (`"$var"` not `$var`)

**Citation**: ShellCheck SC2086; [Google Shell Style Guide](https://google.github.io/styleguide/shellguide.html)

```bash
# WRONG: word splitting and glob expansion
if [ -f $CONFIG_FILE ]; then
    cp $SOURCE $DEST
fi
# If CONFIG_FILE="my file.yaml", this becomes: [ -f my file.yaml ]

# CORRECT: double-quote prevents splitting and globbing
if [[ -f "$CONFIG_FILE" ]]; then
    cp "$SOURCE" "$DEST"
fi
```

---

### HR-7: ALWAYS use `subprocess.run()` with `check=True` in Python (not `os.system`)

**Citation**: [Python subprocess documentation](https://docs.python.org/3/library/subprocess.html); [Google Shell Style Guide](https://google.github.io/styleguide/shellguide.html)

```python
# WRONG: no error handling, shell injection risk, no output capture
import os
os.system(f"pod trunk push {podspec}")

# CORRECT: safe argument list, raises on failure, captures output
import subprocess
result = subprocess.run(
    ["pod", "trunk", "push", podspec, "--allow-warnings"],
    capture_output=True,
    text=True,
    check=True,
    cwd=project_root,
)
print(result.stdout)
```

Error handling pattern:

```python
try:
    result = subprocess.run(
        ["xcodebuild", "-version"],
        capture_output=True, text=True, check=True
    )
except subprocess.CalledProcessError as e:
    print(f"Command failed (exit {e.returncode}): {e.stderr}", file=sys.stderr)
    sys.exit(1)
```

---

### HR-8: ALWAYS add `trap` for cleanup in scripts that create temp files

**Citation**: [MIT SIPB Safe Shell Scripting](https://sipb.mit.edu/doc/safe-shell/)

```bash
# WRONG: temp file leaked on error — fills /tmp over time
TEMP=$(mktemp)
do_work > "$TEMP"
mv "$TEMP" "$OUTPUT"
# If do_work fails, TEMP is never cleaned up
```

```bash
# CORRECT: trap ensures cleanup on EXIT, ERR, INT, TERM
TEMP=$(mktemp)
trap 'rm -f "$TEMP"' EXIT

do_work > "$TEMP"
mv "$TEMP" "$OUTPUT"
# Even if do_work fails, TEMP is removed
```

---

### HR-9: NEVER use bash for scripts >100 lines — use Python

**Citation**: [Google Shell Style Guide](https://google.github.io/styleguide/shellguide.html) — "If you are writing a script that is more than 100 lines long, or that uses non-straightforward control flow logic, you should rewrite it in a more structured language now."

Decision criteria for migration:

| Signal | Action |
|--------|--------|
| Script exceeds 100 lines | Rewrite in Python |
| Needs YAML/JSON data processing | Use Python from the start |
| Needs string templating | Use Python from the start |
| Needs HTTP calls or retries | Use Python from the start |
| Simple file ops + command chaining | Bash is fine |

---

### HR-10: ALWAYS validate inputs at script entry (fail-fast)

**Citation**: Defensive programming; fail-fast principle; Constitution Article VI.1

```bash
# CORRECT: validate everything before doing work
#!/usr/bin/env bash
set -euo pipefail

validate_inputs() {
    if [[ $# -lt 1 ]]; then
        echo "Usage: $0 <config-file>" >&2
        exit 2
    fi
    if [[ ! -f "$1" ]]; then
        echo "ERROR: Config not found: $1" >&2
        exit 1
    fi
    if ! command -v yq &>/dev/null; then
        echo "ERROR: yq is required but not installed" >&2
        exit 1
    fi
}

main() {
    validate_inputs "$@"
    local config="$1"
    # ... safe to proceed ...
}

main "$@"
```

---

### HR-11: ALWAYS use `#!/usr/bin/env bash` (not `#!/bin/bash`)

**Citation**: POSIX portability; [Google Shell Style Guide](https://google.github.io/styleguide/shellguide.html)

```bash
# WRONG: hardcoded path — fails if bash is installed elsewhere (e.g., Homebrew)
#!/bin/bash

# CORRECT: env lookup finds bash wherever it is installed
#!/usr/bin/env bash
```

---

### HR-12: NEVER use `sed -i` without accounting for macOS (BSD vs GNU)

**Citation**: macOS ships BSD sed; Linux ships GNU sed. The `-i` flag is incompatible between them.

```bash
# WRONG: works on Linux, fails on macOS
sed -i 's/old/new/' file.txt

# WRONG: works on macOS, fails on Linux
sed -i '' 's/old/new/' file.txt

# CORRECT: portable approach — temp file + mv (same as atomic write)
sed 's/old/new/' file.txt > file.txt.tmp && mv file.txt.tmp file.txt
```

---

## Advisory Rules (AR)

### AR-1: SHOULD use parameter expansion over external commands

```bash
# Slower: forks a subprocess
filename=$(basename "$path")
extension=$(echo "$file" | grep -oE '\.[^.]+$')

# Faster: pure bash, no fork
filename="${path##*/}"
extension="${file##*.}"
```

### AR-2: SHOULD use `local` for function variables in bash

```bash
my_function() {
    local config_path="$1"       # scoped to function
    local version                 # declare before assignment for commands
    version=$(yq eval '.version' "$config_path")
    echo "$version"
}
```

### AR-3: SHOULD use `argparse` for Python CLI scripts

```python
import argparse

parser = argparse.ArgumentParser(description="Build XCFramework")
parser.add_argument("--config", required=True, help="Path to release.yaml")
parser.add_argument("--dry-run", action="store_true", help="Print commands without executing")
args = parser.parse_args()
```

### AR-4: SHOULD use `--json` output flag for machine-readable script output

```bash
# Human-readable by default, machine-readable on request
if [[ "${OUTPUT_FORMAT:-text}" == "json" ]]; then
    echo "{\"version\": \"${VERSION}\", \"status\": \"success\"}"
else
    echo "Version: ${VERSION} — Build succeeded"
fi
```

### AR-5: SHOULD use `find ... -print0 | xargs -0` for safe file iteration

```bash
# WRONG: breaks on filenames with spaces or newlines
for f in $(find . -name "*.swift"); do echo "$f"; done

# CORRECT: null-delimited, handles any filename
find . -name "*.swift" -print0 | xargs -0 -I{} echo "{}"
```

### AR-6: SHOULD use Python `pathlib` over `os.path`

```python
# os.path — functional, string-based, verbose
import os
config = os.path.join(os.path.dirname(__file__), "..", "config", "release.yaml")

# pathlib — object-oriented, readable, composable
from pathlib import Path
config = Path(__file__).resolve().parent.parent / "config" / "release.yaml"
```

### AR-7: SHOULD log to stderr, output to stdout

```bash
# Diagnostic messages to stderr (not captured by pipes)
echo "INFO: Processing adapters..." >&2
echo "ERROR: Build failed" >&2

# Data output to stdout (captured by pipes and assignment)
echo "$VERSION"
```

### AR-8: SHOULD use exit codes consistently

| Code | Meaning |
|------|---------|
| `0` | Success |
| `1` | General error (runtime failure) |
| `2` | Misuse (bad arguments, missing config) |

---

## AI 常犯错误（本项目特有）

### 1. AI disables `set -euo pipefail` to "fix" errors

```bash
# WRONG: masking errors instead of fixing root cause
set +e
some_failing_command
set -e

# CORRECT: handle the error explicitly
if ! some_failing_command; then
    echo "ERROR: some_failing_command failed" >&2
    exit 1
fi
```

**Why it happens**: AI sees a script fail and removes the safety net rather than fixing the underlying command. This violates Constitution Article I.4 (no manual workarounds).

### 2. AI uses `os.system()` in Python instead of `subprocess.run`

```python
# WRONG: shell injection, no error detection
os.system(f"pod trunk push {podspec}")

# CORRECT: argument list, check=True, no shell
subprocess.run(["pod", "trunk", "push", podspec], check=True)
```

### 3. AI writes >200 line bash scripts (should be Python)

**Signal**: When you see arrays-of-arrays, associative arrays, complex string parsing, or nested conditionals in bash — stop and rewrite in Python.

### 4. AI uses GNU-specific flags on macOS

| GNU (Linux) | BSD (macOS) | Portable Alternative |
|-------------|-------------|----------------------|
| `sed -i` | `sed -i ''` | `sed ... > tmp && mv tmp file` |
| `readlink -f` | N/A | `cd "$(dirname "$0")" && pwd` |
| `date -d "2 days ago"` | `date -j -v-2d` | Python `datetime` |
| `grep -P` | N/A | `grep -E` (extended regex) |

### 5. AI hardcodes `/usr/local/bin` paths instead of using `env`

```bash
# WRONG: assumes Homebrew Intel location
/usr/local/bin/yq eval '.version' config.yaml

# CORRECT: finds yq wherever it is on PATH
yq eval '.version' config.yaml
```

### 6. AI parses YAML with regex/grep instead of yq or pyyaml

This is HR-5 — but AI agents violate it frequently. YAML has multi-line values, anchors, aliases, and flow scalars that regex cannot handle.

### 7. AI forgets to quote variables in bash

This is HR-6. Unquoted variables cause word splitting on spaces and unexpected glob expansion. Every `$variable` in bash should be `"$variable"`.

---

## Config-Driven 开发示例

A complete example showing config-driven development where both Bash and Python read the same YAML and produce identical deterministic output.

### 1. YAML Config (`Scripts/config/release.yaml`)

```yaml
version: "2.1.0"
sdk_name: "MSPCore"
adapters:
  - name: "GoogleMobileAds"
    version: "11.2.0"
    skip_version_update: false
  - name: "Moloco"
    version: "3.0.1"
    skip_version_update: true
```

### 2. Bash Script (reading with yq)

```bash
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
readonly PROJECT_ROOT
readonly CONFIG="${PROJECT_ROOT}/Scripts/config/release.yaml"

main() {
    local version
    version=$(yq eval '.version' "$CONFIG")
    local sdk_name
    sdk_name=$(yq eval '.sdk_name' "$CONFIG")

    echo "Building ${sdk_name} v${version}" >&2

    local adapter_count
    adapter_count=$(yq eval '.adapters | length' "$CONFIG")
    for i in $(seq 0 $((adapter_count - 1))); do
        local name
        name=$(yq eval ".adapters[$i].name" "$CONFIG")
        local ver
        ver=$(yq eval ".adapters[$i].version" "$CONFIG")
        echo "  Adapter: ${name} @ ${ver}" >&2
    done

    echo "$version"  # stdout: machine-readable output
}

main "$@"
```

### 3. Python Script (reading with pyyaml)

```python
#!/usr/bin/env python3
"""Read release config and print build summary."""

import sys
import yaml
from pathlib import Path

def main():
    config_path = Path(__file__).resolve().parent.parent / "config" / "release.yaml"
    with open(config_path) as f:
        config = yaml.safe_load(f)

    version = config["version"]
    sdk_name = config["sdk_name"]

    print(f"Building {sdk_name} v{version}", file=sys.stderr)

    for adapter in config["adapters"]:
        name = adapter["name"]
        ver = adapter["version"]
        print(f"  Adapter: {name} @ {ver}", file=sys.stderr)

    print(version)  # stdout: machine-readable output

if __name__ == "__main__":
    main()
```

Both scripts produce the same stderr log and the same stdout value.

---

## 决策树

### Bash 还是 Python?

```
Task arrives
    |
    ├─ Is it >100 lines or will it grow beyond 100?
    |   └─ Yes --> Python
    |
    ├─ Does it need YAML/JSON data processing beyond simple key lookup?
    |   └─ Yes --> Python
    |
    ├─ Does it need string templating or text generation?
    |   └─ Yes --> Python
    |
    ├─ Does it need HTTP calls, retries, or complex error handling?
    |   └─ Yes --> Python
    |
    ├─ Is it file system operations (cp, mv, find, chmod)?
    |   └─ Yes --> Bash
    |
    ├─ Is it process orchestration (run tools, chain commands)?
    |   └─ Yes --> Bash
    |
    └─ Is it a simple CI pipeline step?
        └─ Yes --> Bash
```

### macOS 兼容性检查

Before using any shell utility, ask: "Is this the GNU or BSD version?"

```
Using sed -i?        --> Use temp file + mv instead
Using readlink -f?   --> Use cd + pwd pattern instead
Using date -d?       --> Use python datetime instead
Using grep -P?       --> Use grep -E instead
Using xargs without -0? --> Add -print0 | xargs -0
```

---

## POSIX vs Bash 对照表

| Operation | Bash / GNU (Linux) | POSIX / BSD (macOS) | Portable Alternative |
|-----------|--------------------|---------------------|----------------------|
| sed in-place | `sed -i 's/a/b/' f` | `sed -i '' 's/a/b/' f` | `sed 's/a/b/' f > tmp && mv tmp f` |
| readlink | `readlink -f path` | No `-f` on macOS | `cd "$(dirname "$0")" && pwd` |
| date arithmetic | `date -d "+2 days"` | `date -j -v+2d` | Python `datetime` |
| mktemp | `mktemp --tmpdir` | `mktemp` | `mktemp "${TMPDIR:-/tmp}/prefix.XXXXX"` |
| grep PCRE | `grep -P '\d+'` | Not available | `grep -E '[0-9]+'` |
| Arrays | `declare -a arr` | Not POSIX | Use Python for array logic |
| Associative arrays | `declare -A map` | Not POSIX | Use Python `dict` |
| `[[ ... ]]` | Supported | Not POSIX `sh` | OK in bash; use `[ ]` for sh |

---

## Never Do

- **NEVER** disable `set -euo pipefail` (HR-1, Constitution Article VI.1)
- **NEVER** hardcode paths or versions (HR-2, Constitution Article I.3)
- **NEVER** parse structured data (YAML/JSON) with regex (HR-5)
- **NEVER** use `os.system()` in Python (HR-7)
- **NEVER** use GNU-specific flags without a macOS fallback (HR-12)
- **NEVER** leave temp files without a `trap` cleanup (HR-8)
- **NEVER** write >100 line bash scripts (HR-9)

---

## 关联 Playbooks

| Playbook | 关系 | 何时参考 |
|----------|------|----------|
| [ctx-ci-001](../../ci/experience/ctx-ci-001-artifact-structure-loss.md) | **下游 — CI 实战** | Artifact 目录结构保持（脚本安全规则的 CI 应用） |
| [ctx-ci-002](../../ci/experience/ctx-ci-002-matrix-artifact-conflict.md) | **下游 — CI 实战** | Matrix 构建命名冲突（config-driven 的 CI 应用） |
| [ctx-ci-003](../../ci/experience/ctx-ci-003-duplicate-build-abi-conflict.md) | **下游 — CI 实战** | 重复构建 ABI 冲突（脚本编排导致的 CI 问题） |
| [ctx-ci-004](../../ci/experience/ctx-ci-004-preinstall-source-dependency.md) | **下游 — CI 实战** | pre_install 依赖顺序（脚本执行时序的 CI 问题） |
| [ctx-release-002](../../release/experience/ctx-release-002.md) | **下游 — 发布实战** | exit code 捕获错误（`set -euo pipefail` 和 PIPESTATUS 的实际案例） |
