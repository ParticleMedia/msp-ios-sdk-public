#!/usr/bin/env python3
"""
Update version string literal in Swift sources (function or property).

Supports:
  - function: func getSDKVersion() -> String { "x.y.z" }
  - property:  var version = "x.y.z"  or  let version = "x.y.z"

Exit codes:
  0: Success (updated or already matches)
  1: Check mode only - version differs
  2: Function/property not found
  3: String literal not found
  4: IO error
"""

from __future__ import annotations

import argparse
import os
import re
import sys
from pathlib import Path


def _replace_first_literal(line: str, version: str) -> tuple[str, bool, bool]:
    match = re.search(r"\"[^\"]*\"", line)
    if not match:
        return line, False, False
    old = match.group(0)[1:-1]
    if old == version:
        return line, True, False
    new_line = line[: match.start()] + f"\"{version}\"" + line[match.end() :]
    return new_line, True, True


def _update_file(path: Path, func_name: str, version: str, check_only: bool) -> tuple[str, bool, bool]:
    try:
        lines = path.read_text(encoding="utf-8").splitlines(keepends=True)
    except OSError:
        return "io_error", False, False

    func_pattern = re.compile(rf"\bfunc\s+{re.escape(func_name)}\s*\(\)\s*->\s*String\b")

    in_func = False
    depth = 0
    found_func = False
    found_literal = False
    changed = False
    mismatch = False
    out: list[str] = []

    for line in lines:
        if not in_func:
            if func_pattern.search(line):
                found_func = True
                in_func = True
                depth += line.count("{") - line.count("}")
                new_line, literal_found, line_changed = _replace_first_literal(line, version)
                if literal_found:
                    found_literal = True
                    if line_changed:
                        changed = True
                        mismatch = True
                    else:
                        mismatch = False
                out.append(new_line)
                if depth <= 0:
                    in_func = False
                continue
            out.append(line)
            continue

        depth += line.count("{") - line.count("}")
        if not found_literal:
            new_line, literal_found, line_changed = _replace_first_literal(line, version)
            if literal_found:
                found_literal = True
                if line_changed:
                    changed = True
                    mismatch = True
                else:
                    mismatch = False
            out.append(new_line)
        else:
            out.append(line)

        if depth <= 0:
            in_func = False

    if not found_func:
        return "function_missing", False, False
    if not found_literal:
        return "literal_missing", False, False

    if check_only:
        return ("mismatch" if mismatch else "match"), False, mismatch

    if changed:
        try:
            path.write_text("".join(out), encoding="utf-8")
        except OSError:
            return "io_error", False, False
    return "updated", changed, False


def _update_file_property(
    path: Path, prop_name: str, version: str, check_only: bool
) -> tuple[str, bool, bool]:
    """Update a Swift property like `var version = "x.y.z"` or `let version = "x.y.z"`."""
    try:
        lines = path.read_text(encoding="utf-8").splitlines(keepends=True)
    except OSError:
        return "io_error", False, False

    # Match: optional modifiers, then var/let, then name, then = and "literal"
    pattern = re.compile(
        rf"^(\s*(?:public\s+|private\s+|internal\s+)*)\b(var|let)\s+{re.escape(prop_name)}\s*=\s*\"([^\"]*)\""
    )
    found = False
    changed = False
    mismatch = False
    out: list[str] = []

    for line in lines:
        m = pattern.search(line)
        if m:
            found = True
            old_version = m.group(3)
            if old_version == version:
                mismatch = False
                out.append(line)
                continue
            mismatch = True
            new_line = line[: m.start(3)] + version + line[m.end(3) :]
            if not check_only:
                changed = True
            out.append(new_line)
        else:
            out.append(line)

    if not found:
        return "function_missing", False, False  # reuse exit code 2
    if check_only:
        return ("mismatch" if mismatch else "match"), False, mismatch
    if changed:
        try:
            path.write_text("".join(out), encoding="utf-8")
        except OSError:
            return "io_error", False, False
    return "updated", changed, False


def main() -> int:
    parser = argparse.ArgumentParser(description="Update getSDKVersion() in Swift adapters.")
    parser.add_argument("--path", required=True, help="Adapter source directory")
    parser.add_argument("--function", required=True, help="Function name to update")
    parser.add_argument("--version", required=True, help="Target SDK version")
    # default "function" keeps existing adapter behavior (getSDKVersion()); "property" for e.g. NovaConstants.version
    parser.add_argument("--pattern", choices=["function", "property"], default="function",
                        help="'function' (default) or 'property' for var/let name = \"...\"")
    parser.add_argument("--check", action="store_true", help="Check-only mode (no writes)")
    args = parser.parse_args()

    root = Path(args.path)
    if not root.exists():
        return 4

    swift_files = [p for p in root.rglob("*.swift") if p.is_file()]
    if not swift_files:
        return 2

    update_fn = _update_file_property if args.pattern == "property" else _update_file
    found_func = False
    found_literal = False
    any_mismatch = False

    for path in swift_files:
        status, _changed, mismatch = update_fn(
            path, args.function, args.version, args.check
        )
        if status == "io_error":
            return 4
        if status == "function_missing":
            continue
        found_func = True
        if status == "literal_missing":
            continue
        found_literal = True
        if status == "mismatch":
            any_mismatch = True

    if not found_func:
        return 2
    if not found_literal:
        return 3
    if args.check and any_mismatch:
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
