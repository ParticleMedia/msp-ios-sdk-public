#!/usr/bin/env python3
"""Generate .context/index.json from context entry frontmatter.

Scans all .context/{domain}/{layer}/ctx-*.md files, extracts YAML
frontmatter, and assembles a machine-readable JSON index.

This script intentionally avoids third-party Python dependencies so the
cross-agent sync chain can run in a clean project environment.
"""

import glob
import json
import os
import re
import subprocess
import sys
import tempfile
from collections import defaultdict
from datetime import datetime, timezone

SCRIPT_PATH = "Scripts/tools/generate-context-index.py"
PROJECT_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
CONTEXT_DIR = os.path.join(PROJECT_ROOT, ".context")
INDEX_PATH = os.path.join(CONTEXT_DIR, "index.json")

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
ID_PATTERN = re.compile(r"^ctx-[a-z]+-\d{3}(-[a-z0-9-]+)?$")
PATH_PATTERN = re.compile(r"^\.context/.+\.md$")
TAG_PATTERN = re.compile(r"^[a-z][a-z0-9-]*$")
VERSION_PATTERN = re.compile(r"^\d+\.\d+$")


def parse_yaml_frontmatter(frontmatter_text):
    """Parse YAML frontmatter via Ruby stdlib YAML and return a dict."""
    ruby_script = r"""
require "date"
require "json"
require "yaml"

def normalize(value)
  case value
  when Hash
    value.transform_values { |v| normalize(v) }
  when Array
    value.map { |v| normalize(v) }
  when Date, Time, DateTime
    value.iso8601
  else
    value
  end
end

data = YAML.safe_load(ARGF.read, permitted_classes: [Date, Time, DateTime], aliases: false)
puts JSON.generate(normalize(data || {}))
"""

    result = subprocess.run(
        ["ruby", "-e", ruby_script],
        input=frontmatter_text,
        text=True,
        capture_output=True,
        check=False,
    )
    if result.returncode != 0:
        raise ValueError(result.stderr.strip() or "Ruby YAML parse failed")

    parsed = json.loads(result.stdout)
    if not isinstance(parsed, dict):
        raise ValueError("Frontmatter must parse to a mapping")
    return parsed


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
        return parse_yaml_frontmatter(frontmatter_text)
    except ValueError as exc:
        print(f"WARNING: YAML parse error in {filepath}: {exc}", file=sys.stderr)
        return None


def find_context_entries():
    """Find all ctx-*.md files in .context/{domain}/{layer}/ directories."""
    pattern = os.path.join(CONTEXT_DIR, "*", "*", "ctx-*.md")
    return sorted(glob.glob(pattern))


def build_index(entries_data):
    """Build the index JSON structure from parsed entries."""
    domain_stats = defaultdict(lambda: {"count": 0, "layers": set()})

    for entry in entries_data:
        domain = entry["domain"]
        domain_stats[domain]["count"] += 1
        domain_stats[domain]["layers"].add(entry["layer"])

    domains = {}
    for domain in VALID_DOMAINS:
        if domain in domain_stats:
            domains[domain] = {
                "count": domain_stats[domain]["count"],
                "layers": sorted(domain_stats[domain]["layers"]),
            }
        else:
            domains[domain] = {"count": 0, "layers": []}

    return {
        "version": "2.0",
        "generated_at": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "generator": SCRIPT_PATH,
        "entry_count": len(entries_data),
        "domains": domains,
        "entries": entries_data,
    }


def is_iso_datetime(value):
    try:
        datetime.strptime(value, "%Y-%m-%dT%H:%M:%SZ")
        return True
    except ValueError:
        return False


def is_iso_date(value):
    try:
        datetime.strptime(value, "%Y-%m-%d")
        return True
    except ValueError:
        return False


def validate_entry(entry):
    """Validate one context entry against the expected shape."""
    required_fields = [
        "id",
        "path",
        "title",
        "domain",
        "layer",
        "tags",
        "triggers",
        "summary",
        "status",
        "updated",
    ]
    for field in required_fields:
        if field not in entry:
            return False, f"entry missing field: {field}"

    if not isinstance(entry["id"], str) or not ID_PATTERN.match(entry["id"]):
        return False, f"invalid entry id: {entry.get('id')}"
    if not isinstance(entry["path"], str) or not PATH_PATTERN.match(entry["path"]):
        return False, f"invalid entry path: {entry.get('path')}"
    if not isinstance(entry["title"], str) or len(entry["title"]) > 120:
        return False, f"invalid entry title: {entry.get('id')}"
    if entry["domain"] not in VALID_DOMAINS:
        return False, f"invalid domain: {entry.get('domain')}"
    if entry["layer"] not in VALID_LAYERS:
        return False, f"invalid layer: {entry.get('layer')}"
    if not isinstance(entry["tags"], list) or len(entry["tags"]) < 2:
        return False, f"invalid tags: {entry.get('id')}"
    if len(set(entry["tags"])) != len(entry["tags"]):
        return False, f"duplicate tags: {entry.get('id')}"
    if not all(isinstance(tag, str) and TAG_PATTERN.match(tag) for tag in entry["tags"]):
        return False, f"invalid tag format: {entry.get('id')}"
    if not isinstance(entry["triggers"], list) or len(entry["triggers"]) < 1:
        return False, f"invalid triggers: {entry.get('id')}"
    if not all(isinstance(trigger, str) for trigger in entry["triggers"]):
        return False, f"invalid trigger type: {entry.get('id')}"
    if not isinstance(entry["summary"], str) or len(entry["summary"]) > 120:
        return False, f"invalid summary: {entry.get('id')}"
    if entry["status"] not in {"active", "archived", "draft"}:
        return False, f"invalid status: {entry.get('id')}"
    if not isinstance(entry["updated"], str) or not is_iso_date(entry["updated"]):
        return False, f"invalid updated date: {entry.get('id')}"
    return True, ""


def validate_index(index_data):
    """Validate generated index without external schema packages."""
    top_required = ["version", "generated_at", "generator", "entry_count", "domains", "entries"]
    for field in top_required:
        if field not in index_data:
            print(f"ERROR: index missing field: {field}", file=sys.stderr)
            return False

    if not isinstance(index_data["version"], str) or not VERSION_PATTERN.match(index_data["version"]):
        print("ERROR: invalid index version", file=sys.stderr)
        return False
    if not isinstance(index_data["generated_at"], str) or not is_iso_datetime(index_data["generated_at"]):
        print("ERROR: invalid generated_at timestamp", file=sys.stderr)
        return False
    if not isinstance(index_data["generator"], str):
        print("ERROR: invalid generator", file=sys.stderr)
        return False
    if not isinstance(index_data["entry_count"], int) or index_data["entry_count"] < 0:
        print("ERROR: invalid entry_count", file=sys.stderr)
        return False
    if not isinstance(index_data["entries"], list):
        print("ERROR: entries must be a list", file=sys.stderr)
        return False
    if index_data["entry_count"] != len(index_data["entries"]):
        print("ERROR: entry_count does not match entries length", file=sys.stderr)
        return False
    if not isinstance(index_data["domains"], dict):
        print("ERROR: domains must be an object", file=sys.stderr)
        return False

    for domain in VALID_DOMAINS:
        if domain not in index_data["domains"]:
            print(f"ERROR: missing domain summary: {domain}", file=sys.stderr)
            return False
        summary = index_data["domains"][domain]
        if not isinstance(summary, dict):
            print(f"ERROR: invalid domain summary type: {domain}", file=sys.stderr)
            return False
        if not isinstance(summary.get("count"), int) or summary["count"] < 0:
            print(f"ERROR: invalid domain count: {domain}", file=sys.stderr)
            return False
        layers = summary.get("layers")
        if not isinstance(layers, list):
            print(f"ERROR: invalid domain layers: {domain}", file=sys.stderr)
            return False
        if len(set(layers)) != len(layers) or any(layer not in VALID_LAYERS for layer in layers):
            print(f"ERROR: invalid domain layer list: {domain}", file=sys.stderr)
            return False

    seen_ids = set()
    for entry in index_data["entries"]:
        ok, message = validate_entry(entry)
        if not ok:
            print(f"ERROR: {message}", file=sys.stderr)
            return False
        if entry["id"] in seen_ids:
            print(f"ERROR: duplicate entry id: {entry['id']}", file=sys.stderr)
            return False
        seen_ids.add(entry["id"])

    return True


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

        rel_path = os.path.relpath(filepath, PROJECT_ROOT).replace(os.sep, "/")
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
        missing = [field for field in required_fields if field not in fm]
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
        for error in errors:
            print(f"WARNING: {error}", file=sys.stderr)

    index_data = build_index(entries)

    if not validate_index(index_data):
        sys.exit(1)

    fd, tmp_path = tempfile.mkstemp(dir=CONTEXT_DIR, suffix=".json")
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as file:
            json.dump(index_data, file, indent=2, ensure_ascii=False)
            file.write("\n")
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
