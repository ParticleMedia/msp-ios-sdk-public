#!/usr/bin/env python3
"""
test-cases.py - Test case management tool (YAML)

Commands:
    validate          Check YAML files for schema compliance, ID duplicates, prefix conflicts
    sync              Check if Swift tests implement all defined test cases
    coverage          Show implementation status aggregated by bundle
    regression-report List bugfix branches with/without regression test cases

Usage:
    python Scripts/tools/test-cases.py validate
    python Scripts/tools/test-cases.py sync
    python Scripts/tools/test-cases.py coverage
    python Scripts/tools/test-cases.py regression-report
    python Scripts/tools/test-cases.py validate sync coverage  # Run all (for CI)
    python Scripts/tools/test-cases.py validate --strict       # Require jsonschema
"""

import re
import sys
from pathlib import Path
from typing import Dict, List, Set, Tuple

try:
    import yaml
except ImportError:
    print("ERROR: pyyaml not installed. Run: pip install pyyaml")
    sys.exit(1)

try:
    import jsonschema
except ImportError:
    jsonschema = None

# Configuration
TEST_CASES_DIR = "packages/test-cases"
TESTS_DIR = "Tests"
MOCK_DATA_DIR = "packages/mock-data"
PREFIXES_FILE = "_prefixes.yaml"
SCHEMA_FILE = "_schema.yaml"
ID_PATTERN = re.compile(r"\[([A-Z]{2,4}\d{3})\]")


def find_project_root() -> Path:
    """Find project root by looking for packages/test-cases directory."""
    current = Path.cwd()
    for _ in range(10):
        if (current / TEST_CASES_DIR).exists():
            return current
        parent = current.parent
        if parent == current:
            break
        current = parent
    print(
        f"ERROR: Could not find project root ({TEST_CASES_DIR} not found)",
        file=sys.stderr,
    )
    sys.exit(1)


def load_yaml(path: Path) -> dict:
    """Load YAML file."""
    with open(path, "r") as f:
        return yaml.safe_load(f) or {}


def get_test_case_files(test_cases_dir: Path) -> List[Path]:
    """Get all test case YAML files (excluding templates, registry, schema)."""
    return sorted(
        f
        for f in test_cases_dir.rglob("*.yaml")
        if not f.name.startswith("_") and not f.name.startswith(".")
    )


# =============================================================================
# VALIDATE COMMAND
# =============================================================================


def validate(
    test_cases_dir: Path,
    project_root: Path,
    verbose: bool = False,
    strict: bool = False,
) -> bool:
    """Validate test case YAML files."""
    print("=" * 60)
    print("VALIDATE: Checking test case YAML files")
    print("=" * 60)

    has_errors = False

    # Load prefix registry
    prefixes_path = test_cases_dir / PREFIXES_FILE
    registry = {}
    if prefixes_path.exists():
        data = load_yaml(prefixes_path)
        registry = data.get("prefixes", {})
    else:
        print(f"\n⚠ Warning: {PREFIXES_FILE} not found")

    # Load schema for validation
    schema = None
    schema_path = test_cases_dir / SCHEMA_FILE
    if schema_path.exists() and jsonschema is not None:
        schema = load_yaml(schema_path)
    elif strict and jsonschema is None:
        print("\n✗ jsonschema not installed (required in --strict mode)")
        print("   Run: pip install jsonschema")
        has_errors = True

    # Collect all IDs and prefixes
    id_to_files: Dict[str, List[str]] = {}
    prefix_to_modules: Dict[str, List[str]] = {}
    unregistered_prefixes: List[Tuple[str, str]] = []
    fixture_warnings: List[str] = []

    yaml_files = get_test_case_files(test_cases_dir)

    for yaml_file in yaml_files:
        try:
            data = load_yaml(yaml_file)
        except Exception as e:
            print(f"\n✗ Error loading {yaml_file.name}: {e}")
            has_errors = True
            continue

        module = data.get("module", "unknown")
        prefix = data.get("prefix")
        cases = data.get("cases", [])

        # Schema validation
        if schema is not None:
            try:
                jsonschema.validate(instance=data, schema=schema)
            except jsonschema.ValidationError as e:
                print(f"\n✗ Schema validation failed for {yaml_file.name}:")
                print(f"   {e.message}")
                has_errors = True

        # Check prefix registration
        if prefix:
            if prefix in registry:
                if registry[prefix] != module:
                    print(
                        f"\n✗ Prefix '{prefix}' registered for '{registry[prefix]}' but used by '{module}'"
                    )
                    has_errors = True
            else:
                unregistered_prefixes.append((prefix, module))

            prefix_to_modules.setdefault(prefix, []).append(module)

        # Collect IDs and validate fixtures
        for case in cases:
            case_id = case.get("id")
            if case_id:
                rel_path = yaml_file.relative_to(test_cases_dir)
                id_to_files.setdefault(case_id, []).append(str(rel_path))

            # Fixture validation (warn only)
            for fixture in case.get("fixtures", []):
                fixture_path = project_root / MOCK_DATA_DIR / fixture
                if not fixture_path.exists():
                    fixture_warnings.append(
                        f"{case.get('id', '?')}: fixture '{fixture}' not found in {MOCK_DATA_DIR}/"
                    )

    # Check for duplicate IDs
    print("\n1. Checking for duplicate IDs...")
    duplicates = {id_: files for id_, files in id_to_files.items() if len(files) > 1}

    if duplicates:
        print(f"   ✗ Found {len(duplicates)} duplicate ID(s):")
        for id_, files in sorted(duplicates.items()):
            print(f"      {id_}: {', '.join(files)}")
        has_errors = True
    else:
        print(f"   ✓ No duplicate IDs ({len(id_to_files)} unique)")

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

    # Schema check status
    if schema is not None:
        print("\n4. Schema validation...")
        if not has_errors:
            print("   ✓ All files pass schema validation")
        else:
            print("   ✗ Schema validation had errors (see above)")
    else:
        print("\n4. Schema validation... skipped (jsonschema not installed)")

    # Fixture warnings
    print("\n5. Checking fixture references...")
    if fixture_warnings:
        print(f"   ⚠ {len(fixture_warnings)} fixture warning(s):")
        for warning in fixture_warnings:
            print(f"      {warning}")
    else:
        print("   ✓ No fixture issues")

    # Summary
    print("\n" + "-" * 60)
    if has_errors:
        print("VALIDATE: ✗ FAILED")
    else:
        print(f"VALIDATE: ✓ PASSED ({len(yaml_files)} files, {len(id_to_files)} cases)")

    return not has_errors


# =============================================================================
# SYNC COMMAND
# =============================================================================


def find_swift_test_files_v1(tests_dir: Path, module: str) -> List[Path]:
    """Find Swift test files matching the module name (v1.0 fuzzy matching)."""
    results = []
    module_lower = module.lower()

    for swift_file in tests_dir.rglob("*.swift"):
        name_lower = swift_file.name.lower()
        if module_lower in name_lower and (
            "spec" in name_lower or "test" in name_lower
        ):
            results.append(swift_file)

    return results


def find_swift_test_files_v2(
    project_root: Path, cases: list
) -> Dict[str, List[Path]]:
    """Build a map of case_id -> [swift file paths] using the v2 file field.

    Returns only entries where the case has a `file` field.
    """
    result: Dict[str, List[Path]] = {}
    for case in cases:
        case_id = case.get("id")
        file_path = case.get("file")
        if case_id and file_path:
            resolved = project_root / file_path
            if resolved.exists():
                result[case_id] = [resolved]
            else:
                result[case_id] = []
    return result


def extract_implemented_ids(swift_file: Path) -> Set[str]:
    """Extract test case IDs from Swift file using regex."""
    content = swift_file.read_text()
    return set(ID_PATTERN.findall(content))


def sync(
    test_cases_dir: Path,
    tests_dir: Path,
    project_root: Path,
    verbose: bool = False,
) -> bool:
    """Check if Swift tests implement all defined test cases."""
    print("=" * 60)
    print("SYNC: Checking test implementation status")
    print("=" * 60)

    yaml_files = get_test_case_files(test_cases_dir)

    if not yaml_files:
        print("\nNo test case files found.")
        return True

    total_defined = 0
    total_implemented = 0
    total_missing = 0
    total_planned = 0
    total_skipped = 0
    has_missing = False

    print()

    for yaml_file in yaml_files:
        try:
            data = load_yaml(yaml_file)
        except Exception as e:
            print(f"✗ Error loading {yaml_file.name}: {e}")
            continue

        module = data.get("module", "unknown")
        prefix = data.get("prefix", "")
        cases = data.get("cases", [])

        # Separate cases by status
        implementable_ids: Set[str] = set()
        planned_count = 0
        skipped_count = 0

        for case in cases:
            case_id = case.get("id")
            if not case_id:
                continue
            status = case.get("status", "implemented")
            if status == "planned":
                planned_count += 1
            elif status == "skipped":
                skipped_count += 1
            else:
                implementable_ids.add(case_id)

        total_planned += planned_count
        total_skipped += skipped_count

        # v2: use file field for direct path resolution when available
        v2_map = find_swift_test_files_v2(project_root, cases)
        has_v2_files = any(paths for paths in v2_map.values())

        implemented_ids: Set[str] = set()

        if has_v2_files:
            # v2 path: collect unique files from the file field
            unique_files: Set[Path] = set()
            for paths in v2_map.values():
                unique_files.update(paths)
            for swift_file in unique_files:
                implemented_ids.update(extract_implemented_ids(swift_file))

            # Warn when a case's file exists but its ID marker is missing
            for case in cases:
                case_id = case.get("id")
                file_path = case.get("file")
                status = case.get("status", "implemented")
                if (
                    case_id
                    and file_path
                    and status == "implemented"
                    and case_id in v2_map
                    and v2_map[case_id]
                    and case_id not in implemented_ids
                ):
                    print(
                        f"   ⚠ {case_id} declares file {file_path} but [{case_id}] marker not found"
                    )
        else:
            # v1 fallback: fuzzy match by module name
            swift_files = find_swift_test_files_v1(tests_dir, module)
            for swift_file in swift_files:
                implemented_ids.update(extract_implemented_ids(swift_file))

        # Calculate stats (only for implementable cases)
        matched = implementable_ids & implemented_ids
        missing = implementable_ids - implemented_ids

        total_defined += len(implementable_ids)
        total_implemented += len(matched)
        total_missing += len(missing)

        # Print result
        prefix_str = f"[{prefix}] " if prefix else ""
        status_char = "✓" if not missing else "✗"
        extra = ""
        if planned_count or skipped_count:
            parts = []
            if planned_count:
                parts.append(f"{planned_count} planned")
            if skipped_count:
                parts.append(f"{skipped_count} skipped")
            extra = f" ({', '.join(parts)})"

        print(
            f"{status_char} {prefix_str}{module}: {len(matched)}/{len(implementable_ids)} implemented{extra}"
        )

        if missing:
            has_missing = True
            if verbose or len(missing) <= 5:
                for id_ in sorted(missing):
                    print(f"   - {id_} missing")
            else:
                print(
                    f"   ... {len(missing)} test(s) missing (use --verbose to see all)"
                )

    # Summary
    print("\n" + "-" * 60)
    print(f"Summary: {total_implemented}/{total_defined} test cases implemented")
    if total_missing > 0:
        print(f"         {total_missing} test case(s) missing")
    if total_planned > 0:
        print(f"         {total_planned} test case(s) planned")
    if total_skipped > 0:
        print(f"         {total_skipped} test case(s) skipped")

    if total_missing > 0:
        print("\nSYNC: ✗ FAILED")
    else:
        print("\nSYNC: ✓ PASSED")

    return not has_missing


# =============================================================================
# COVERAGE COMMAND
# =============================================================================


def coverage(test_cases_dir: Path, verbose: bool = False) -> bool:
    """Show implementation status aggregated by bundle. Always returns True (informational)."""
    print("=" * 60)
    print("COVERAGE: Test case status by bundle")
    print("=" * 60)

    yaml_files = get_test_case_files(test_cases_dir)

    if not yaml_files:
        print("\nNo test case files found.")
        return True

    # Aggregate by bundle
    bundles: Dict[str, Dict[str, int]] = {}

    for yaml_file in yaml_files:
        try:
            data = load_yaml(yaml_file)
        except Exception:
            continue

        bundle = data.get("bundle", "unknown")
        cases = data.get("cases", [])

        if bundle not in bundles:
            bundles[bundle] = {"implemented": 0, "planned": 0, "skipped": 0}

        for case in cases:
            status = case.get("status", "implemented")
            if status in bundles[bundle]:
                bundles[bundle][status] += 1

    print()
    total_all = 0
    for bundle in sorted(bundles.keys()):
        counts = bundles[bundle]
        impl = counts["implemented"]
        plan = counts["planned"]
        skip = counts["skipped"]
        total = impl + plan + skip
        total_all += total

        parts = [f"{impl} implemented"]
        if plan:
            parts.append(f"{plan} planned")
        if skip:
            parts.append(f"{skip} skipped")

        print(f"  {bundle}: {total} total ({', '.join(parts)})")

    print(f"\n  Total: {total_all} test cases across {len(bundles)} bundle(s)")
    print("\n" + "-" * 60)
    print("COVERAGE: ✓ OK (informational)")

    return True


# =============================================================================
# REGRESSION-REPORT COMMAND
# =============================================================================


def regression_report(test_cases_dir: Path, verbose: bool = False) -> bool:
    """List test cases with regression_for field and their coverage status."""
    print("=" * 60)
    print("REGRESSION: Test cases guarding bugfixes")
    print("=" * 60)

    yaml_files = get_test_case_files(test_cases_dir)
    regression_cases = []

    for yaml_file in yaml_files:
        try:
            data = load_yaml(yaml_file)
        except Exception:
            continue

        module = data.get("module", "unknown")
        for case in data.get("cases", []):
            if case.get("regression_for"):
                regression_cases.append(
                    {
                        "id": case.get("id", "?"),
                        "module": module,
                        "regression_for": case.get("regression_for", ""),
                        "description": case.get("description", ""),
                    }
                )

    if not regression_cases:
        print("\nNo regression test cases found.")
        print("Add regression_for field to test cases guarding bugfixes.")
        return True

    print(f"\nFound {len(regression_cases)} regression test case(s):\n")
    for rc in regression_cases:
        print(f"  [{rc['id']}] {rc['description']}")
        print(f"    Guards: {rc['regression_for']}")
        print()

    return True


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
    strict = "--strict" in args
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
            results.append(validate(test_cases_dir, project_root, verbose, strict))
            print()
        elif cmd == "sync":
            results.append(sync(test_cases_dir, tests_dir, project_root, verbose))
            print()
        elif cmd == "coverage":
            results.append(coverage(test_cases_dir, verbose))
            print()
        elif cmd == "regression-report":
            results.append(regression_report(test_cases_dir, verbose))
            print()
        else:
            print(f"Unknown command: {cmd}")
            print_help()
            sys.exit(1)

    if not all(results):
        sys.exit(1)


if __name__ == "__main__":
    main()
