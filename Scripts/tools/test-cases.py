#!/usr/bin/env python3
"""
test-cases.py - Test case management tool

Commands:
    validate    Check JSON files for ID duplicates and prefix conflicts
    sync        Check if Swift tests implement all defined test cases

Usage:
    python Scripts/tools/test-cases.py validate
    python Scripts/tools/test-cases.py sync
    python Scripts/tools/test-cases.py validate sync  # Run both (for CI)
"""

import json
import re
import sys
from pathlib import Path
from typing import Dict, List, Set, Tuple

# Configuration
TEST_CASES_DIR = "Tests/TestCases"
TESTS_DIR = "Tests"
PREFIXES_FILE = "_prefixes.json"
ID_PATTERN = re.compile(r'\[([A-Z]{2,4}\d{3})\]')


def find_project_root() -> Path:
    """Find project root by looking for Tests/TestCases directory."""
    current = Path.cwd()
    for _ in range(10):
        if (current / TEST_CASES_DIR).exists():
            return current
        parent = current.parent
        if parent == current:
            break
        current = parent
    return Path.cwd()


def load_json(path: Path) -> dict:
    """Load JSON file."""
    with open(path, 'r') as f:
        return json.load(f)


def get_test_case_files(test_cases_dir: Path) -> List[Path]:
    """Get all test case JSON files (excluding templates and registry)."""
    return [
        f for f in test_cases_dir.glob("*.json")
        if not f.name.startswith("_") and not f.name.startswith(".")
    ]


# =============================================================================
# VALIDATE COMMAND
# =============================================================================

def validate(test_cases_dir: Path, verbose: bool = False) -> bool:
    """
    Validate test case JSON files:
    1. Check for duplicate IDs across files
    2. Check prefix registry consistency
    3. Check for prefix conflicts

    Returns True if all checks pass.
    """
    print("=" * 60)
    print("VALIDATE: Checking test case JSON files")
    print("=" * 60)

    has_errors = False

    # Load prefix registry
    prefixes_path = test_cases_dir / PREFIXES_FILE
    registry = {}
    if prefixes_path.exists():
        data = load_json(prefixes_path)
        registry = data.get("prefixes", {})
    else:
        print(f"\n⚠ Warning: {PREFIXES_FILE} not found")

    # Collect all IDs and prefixes from JSON files
    id_to_files: Dict[str, List[str]] = {}
    prefix_to_modules: Dict[str, List[str]] = {}
    unregistered_prefixes: List[Tuple[str, str]] = []

    json_files = get_test_case_files(test_cases_dir)

    for json_file in json_files:
        try:
            data = load_json(json_file)
        except Exception as e:
            print(f"\n✗ Error loading {json_file.name}: {e}")
            has_errors = True
            continue

        module = data.get("module", "unknown")
        prefix = data.get("prefix")
        cases = data.get("cases", [])

        # Check prefix registration
        if prefix:
            if prefix in registry:
                if registry[prefix] != module:
                    print(f"\n✗ Prefix '{prefix}' registered for '{registry[prefix]}' but used by '{module}'")
                    has_errors = True
            else:
                unregistered_prefixes.append((prefix, module))

            prefix_to_modules.setdefault(prefix, []).append(module)

        # Collect IDs
        for case in cases:
            case_id = case.get("id")
            if case_id:
                id_to_files.setdefault(case_id, []).append(json_file.name)

    # Check for duplicate IDs
    print("\n1. Checking for duplicate IDs...")
    duplicates = {id_: files for id_, files in id_to_files.items() if len(files) > 1}

    if duplicates:
        print(f"   ✗ Found {len(duplicates)} duplicate ID(s):")
        for id_, files in sorted(duplicates.items()):
            print(f"      {id_}: {', '.join(files)}")
        has_errors = True
    else:
        print("   ✓ No duplicate IDs")

    # Check for prefix conflicts
    print("\n2. Checking for prefix conflicts...")
    conflicts = {p: m for p, m in prefix_to_modules.items() if len(m) > 1}

    if conflicts:
        print(f"   ✗ Found {len(conflicts)} prefix conflict(s):")
        for prefix, modules in sorted(conflicts.items()):
            print(f"      '{prefix}' used by: {', '.join(modules)}")
        has_errors = True
    else:
        print("   ✓ No prefix conflicts")

    # Check unregistered prefixes
    print("\n3. Checking prefix registry...")
    if unregistered_prefixes:
        print(f"   ✗ Found {len(unregistered_prefixes)} unregistered prefix(es):")
        for prefix, module in unregistered_prefixes:
            print(f"      '{prefix}' used by '{module}' - add to {PREFIXES_FILE}")
        has_errors = True
    else:
        print("   ✓ All prefixes registered")

    # Summary
    print("\n" + "-" * 60)
    if has_errors:
        print("VALIDATE: ✗ FAILED")
    else:
        print("VALIDATE: ✓ PASSED")

    return not has_errors


# =============================================================================
# SYNC COMMAND
# =============================================================================

def find_swift_test_files(tests_dir: Path, module: str) -> List[Path]:
    """Find Swift test files matching the module name."""
    results = []
    module_lower = module.lower()

    for swift_file in tests_dir.rglob("*.swift"):
        name_lower = swift_file.name.lower()
        if module_lower in name_lower and ("spec" in name_lower or "test" in name_lower):
            results.append(swift_file)

    return results


def extract_implemented_ids(swift_file: Path) -> Set[str]:
    """Extract test case IDs from Swift file using regex."""
    content = swift_file.read_text()
    return set(ID_PATTERN.findall(content))


def sync(test_cases_dir: Path, tests_dir: Path, verbose: bool = False) -> bool:
    """
    Check if Swift tests implement all defined test cases.

    Returns True if all test cases are implemented.
    """
    print("=" * 60)
    print("SYNC: Checking test implementation status")
    print("=" * 60)

    json_files = get_test_case_files(test_cases_dir)

    if not json_files:
        print("\nNo test case files found.")
        return True

    total_defined = 0
    total_implemented = 0
    total_missing = 0
    has_missing = False

    print()

    for json_file in sorted(json_files):
        try:
            data = load_json(json_file)
        except Exception as e:
            print(f"✗ Error loading {json_file.name}: {e}")
            continue

        module = data.get("module", "unknown")
        prefix = data.get("prefix", "")
        cases = data.get("cases", [])

        defined_ids = {case.get("id") for case in cases if case.get("id")}

        # Find implemented IDs in Swift files
        swift_files = find_swift_test_files(tests_dir, module)
        implemented_ids: Set[str] = set()

        for swift_file in swift_files:
            implemented_ids.update(extract_implemented_ids(swift_file))

        # Calculate stats
        matched = defined_ids & implemented_ids
        missing = defined_ids - implemented_ids

        total_defined += len(defined_ids)
        total_implemented += len(matched)
        total_missing += len(missing)

        # Print result
        prefix_str = f"[{prefix}] " if prefix else ""
        status = "✓" if not missing else "✗"

        print(f"{status} {prefix_str}{module}: {len(matched)}/{len(defined_ids)} implemented")

        if missing:
            has_missing = True
            if verbose or len(missing) <= 5:
                for id_ in sorted(missing):
                    print(f"   - {id_} missing")
            else:
                print(f"   ... {len(missing)} test(s) missing (use --verbose to see all)")

    # Summary
    print("\n" + "-" * 60)
    print(f"Summary: {total_implemented}/{total_defined} test cases implemented")
    if total_missing > 0:
        print(f"         {total_missing} test case(s) missing")
        print("\nSYNC: ✗ FAILED")
    else:
        print("\nSYNC: ✓ PASSED")

    return not has_missing


# =============================================================================
# MAIN
# =============================================================================

def print_help():
    print(__doc__)


def main():
    args = sys.argv[1:]

    if not args or "--help" in args or "-h" in args:
        print_help()
        sys.exit(0)

    verbose = "--verbose" in args or "-v" in args
    args = [a for a in args if not a.startswith("-")]

    project_root = find_project_root()
    test_cases_dir = project_root / TEST_CASES_DIR
    tests_dir = project_root / TESTS_DIR

    if not test_cases_dir.exists():
        print(f"Error: {TEST_CASES_DIR} not found")
        sys.exit(1)

    results = []

    for cmd in args:
        if cmd == "validate":
            results.append(validate(test_cases_dir, verbose))
            print()
        elif cmd == "sync":
            results.append(sync(test_cases_dir, tests_dir, verbose))
            print()
        else:
            print(f"Unknown command: {cmd}")
            print_help()
            sys.exit(1)

    # Exit with error if any command failed
    if not all(results):
        sys.exit(1)


if __name__ == "__main__":
    main()
