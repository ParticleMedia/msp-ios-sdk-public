#!/usr/bin/env python3
"""
migrate-test-cases.py - Migrate test cases from JSON to YAML format.

Reads Tests/TestCases/*.json and writes packages/test-cases/{subdir}/{Module}.yaml.
Preserves all IDs and metadata with zero data loss.

Usage:
    python Scripts/tools/migrate-test-cases.py [--dry-run]
"""

import json
import os
import sys
import tempfile
from datetime import date
from pathlib import Path

try:
    import yaml
except ImportError:
    print("ERROR: pyyaml not installed. Run: pip install pyyaml")
    sys.exit(1)


def find_project_root() -> Path:
    """Find project root by looking for Tests/TestCases directory."""
    current = Path.cwd()
    for _ in range(10):
        if (current / "Tests" / "TestCases").exists():
            return current
        parent = current.parent
        if parent == current:
            break
        current = parent
    return Path.cwd()


def load_json(path: Path) -> dict:
    """Load JSON file."""
    with open(path, "r") as f:
        return json.load(f)


def convert_case(case: dict) -> dict:
    """Convert a single test case from JSON to YAML-compatible dict.

    Transforms object-style given/when/then to string-style for schema compliance.
    """
    result = {}

    # Required fields first
    result["id"] = case["id"]
    result["type"] = case["type"]
    result["description"] = case.get("description", case.get("scenario", ""))

    # Optional metadata
    if "priority" in case:
        result["priority"] = case["priority"]
    if "tags" in case:
        result["tags"] = case["tags"]

    # BDD fields
    if case["type"] == "behavior":
        given = case.get("given", [])
        when_val = case.get("when", "")
        then_val = case.get("then", [])

        # Convert arrays to joined strings
        if isinstance(given, list):
            result["given"] = "; ".join(given)
        else:
            result["given"] = str(given)

        result["when"] = str(when_val)

        if isinstance(then_val, list):
            result["then"] = "; ".join(then_val)
        else:
            result["then"] = str(then_val)

    # Unit test fields
    if case["type"] == "unit":
        if "class" in case:
            result["class"] = case["class"]
        if "method" in case:
            result["method"] = case["method"]

    # Doubles placeholder (to be filled in T042/T042a)
    result["doubles"] = {}

    return result


def migrate_module(json_path: Path, output_dir: Path, dry_run: bool = False) -> bool:
    """Migrate a single JSON test case file to YAML."""
    data = load_json(json_path)

    module = data.get("module", "unknown")
    prefix = data.get("prefix", "")
    description = data.get("description", "")
    cases = data.get("cases", [])

    today = date.today().isoformat()

    yaml_data = {
        "module": module,
        "prefix": prefix,
        "description": description,
        "created": today,
        "updated": today,
        "cases": [convert_case(c) for c in cases],
    }

    output_path = output_dir / f"{module}.yaml"

    if dry_run:
        print(f"  [DRY RUN] Would write {output_path}")
        print(f"    Module: {module}, Prefix: {prefix}, Cases: {len(cases)}")
        return True

    # Atomic write
    output_dir.mkdir(parents=True, exist_ok=True)
    fd, tmp_path = tempfile.mkstemp(suffix=".yaml", dir=str(output_dir))
    try:
        with os.fdopen(fd, "w") as f:
            yaml.dump(
                yaml_data,
                f,
                default_flow_style=False,
                allow_unicode=True,
                sort_keys=False,
                width=120,
            )
        os.replace(tmp_path, str(output_path))
    except Exception:
        os.unlink(tmp_path)
        raise

    print(f"  ✓ {json_path.name} → {output_path.relative_to(output_dir.parent.parent)}")
    print(f"    {len(cases)} cases migrated ({prefix}001-{prefix}{len(cases):03d})")
    return True


def main():
    dry_run = "--dry-run" in sys.argv

    project_root = find_project_root()
    json_dir = project_root / "Tests" / "TestCases"
    output_base = project_root / "packages" / "test-cases" / "debug"

    if not json_dir.exists():
        print(f"ERROR: {json_dir} not found")
        sys.exit(1)

    json_files = sorted(
        f
        for f in json_dir.glob("*.json")
        if not f.name.startswith("_") and not f.name.startswith(".")
    )

    if not json_files:
        print("No JSON test case files found.")
        sys.exit(0)

    print(f"Migrating {len(json_files)} test case file(s)...")
    print(f"  Source: {json_dir}")
    print(f"  Target: {output_base}")
    print()

    success = True
    total_cases = 0

    for json_file in json_files:
        try:
            data = load_json(json_file)
            total_cases += len(data.get("cases", []))
            if not migrate_module(json_file, output_base, dry_run):
                success = False
        except Exception as e:
            print(f"  ✗ Error migrating {json_file.name}: {e}")
            success = False

    print()
    if success:
        print(f"Migration complete: {len(json_files)} files, {total_cases} cases.")
    else:
        print("Migration completed with errors.")
        sys.exit(1)


if __name__ == "__main__":
    main()
