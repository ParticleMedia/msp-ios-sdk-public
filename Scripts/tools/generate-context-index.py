#!/usr/bin/env python3
"""Generate .context/index.json from context entry frontmatter.

Scans all .context/{domain}/{layer}/ctx-*.md files, extracts YAML
frontmatter, and assembles a machine-readable JSON index validated
against .context/index.schema.json.

Usage:
    python Scripts/tools/generate-context-index.py
"""

import glob
import json
import os
import sys
import tempfile
from collections import defaultdict
from datetime import datetime, timezone

import yaml

try:
    import jsonschema
except ImportError:
    print(
        "ERROR: jsonschema package required. Run: pip install jsonschema",
        file=sys.stderr,
    )
    sys.exit(1)

SCRIPT_PATH = "Scripts/tools/generate-context-index.py"
PROJECT_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
CONTEXT_DIR = os.path.join(PROJECT_ROOT, ".context")
INDEX_PATH = os.path.join(CONTEXT_DIR, "index.json")
SCHEMA_PATH = os.path.join(CONTEXT_DIR, "index.schema.json")

VALID_DOMAINS = {
    "release",
    "ci",
    "integration",
    "compatibility",
    "testing",
    "sources",
    "architecture",
}
VALID_LAYERS = {"business", "experience", "tech"}


def extract_frontmatter(filepath):
    """Extract YAML frontmatter from a Markdown file."""
    with open(filepath, "r", encoding="utf-8") as f:
        content = f.read()

    if not content.startswith("---"):
        return None

    end = content.find("---", 3)
    if end == -1:
        return None

    frontmatter_text = content[3:end].strip()
    try:
        return yaml.safe_load(frontmatter_text)
    except yaml.YAMLError as e:
        print(f"WARNING: YAML parse error in {filepath}: {e}", file=sys.stderr)
        return None


def find_context_entries():
    """Find all ctx-*.md files in .context/{domain}/{layer}/ directories."""
    pattern = os.path.join(CONTEXT_DIR, "*", "*", "ctx-*.md")
    return sorted(glob.glob(pattern))


def build_index(entries_data):
    """Build the index JSON structure from parsed entries."""
    domain_stats = defaultdict(lambda: {"count": 0, "layers": set()})

    for entry in entries_data:
        d = entry["domain"]
        domain_stats[d]["count"] += 1
        domain_stats[d]["layers"].add(entry["layer"])

    domains = {}
    for d in VALID_DOMAINS:
        if d in domain_stats:
            domains[d] = {
                "count": domain_stats[d]["count"],
                "layers": sorted(domain_stats[d]["layers"]),
            }
        else:
            domains[d] = {"count": 0, "layers": []}

    return {
        "version": "2.0",
        "generated_at": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "generator": SCRIPT_PATH,
        "entry_count": len(entries_data),
        "domains": domains,
        "entries": entries_data,
    }


def validate_index(index_data):
    """Validate index against JSON Schema."""
    if not os.path.exists(SCHEMA_PATH):
        print(
            f"WARNING: Schema not found at {SCHEMA_PATH}, skipping validation",
            file=sys.stderr,
        )
        return True

    with open(SCHEMA_PATH, "r", encoding="utf-8") as f:
        schema = json.load(f)

    try:
        jsonschema.validate(instance=index_data, schema=schema)
        return True
    except jsonschema.ValidationError as e:
        print(f"ERROR: Schema validation failed: {e.message}", file=sys.stderr)
        print(f"  Path: {'.'.join(str(p) for p in e.absolute_path)}", file=sys.stderr)
        return False


def main():
    if not os.path.isdir(CONTEXT_DIR):
        print(f"ERROR: Context directory not found: {CONTEXT_DIR}", file=sys.stderr)
        sys.exit(1)

    files = find_context_entries()
    if not files:
        print("WARNING: No context entry files found", file=sys.stderr)

    entries = []
    errors = []

    for filepath in files:
        fm = extract_frontmatter(filepath)
        if fm is None:
            errors.append(f"No valid frontmatter: {filepath}")
            continue

        rel_path = os.path.relpath(filepath, PROJECT_ROOT)
        # Normalize to forward slashes and ensure leading dot
        rel_path = rel_path.replace(os.sep, "/")
        if not rel_path.startswith(".context/"):
            rel_path = ".context/" + rel_path.split(".context/", 1)[-1]

        required_fields = [
            "id",
            "title",
            "domain",
            "layer",
            "tags",
            "triggers",
            "summary",
            "status",
        ]
        missing = [f for f in required_fields if f not in fm]
        if missing:
            errors.append(f"Missing fields {missing} in {filepath}")
            continue

        if fm.get("status") != "active":
            continue

        updated_val = fm.get("updated", "2026-02-22")
        if not isinstance(updated_val, str):
            updated_val = str(updated_val)

        entry = {
            "id": fm["id"],
            "path": rel_path,
            "title": fm["title"],
            "domain": fm["domain"],
            "layer": fm["layer"],
            "tags": fm["tags"],
            "triggers": fm["triggers"],
            "summary": fm["summary"],
            "status": fm["status"],
            "updated": updated_val,
        }
        entries.append(entry)

    if errors:
        for e in errors:
            print(f"WARNING: {e}", file=sys.stderr)

    index_data = build_index(entries)

    if not validate_index(index_data):
        sys.exit(1)

    # Atomic write: tempfile + rename
    fd, tmp_path = tempfile.mkstemp(dir=CONTEXT_DIR, suffix=".json")
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as f:
            json.dump(index_data, f, indent=2, ensure_ascii=False)
            f.write("\n")
        os.replace(tmp_path, INDEX_PATH)
    except Exception:
        os.unlink(tmp_path)
        raise

    print(f"Index generated: {INDEX_PATH}")
    print(f"  Entries: {index_data['entry_count']}")
    for domain, stats in sorted(index_data["domains"].items()):
        if stats["count"] > 0:
            print(f"  {domain}: {stats['count']} ({', '.join(stats['layers'])})")


if __name__ == "__main__":
    main()
