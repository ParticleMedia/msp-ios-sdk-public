#!/usr/bin/env python3
"""Synchronize agent rule files from shared sources of truth.

Reads .context/index.json and .agents-shared/skills/ to regenerate
marker-delimited sections in agent-specific rule files across
Claude, Cursor, and Codex.

This script is the SINGLE mechanism for keeping agent configs in sync.
It should be called after any of these changes:
  - New .context/ entry added (via add-context.sh)
  - .context/index.json regenerated (via generate-context-index.py)
  - New skill added to .agents-shared/skills/
  - Skill file modified

Usage:
    python Scripts/tools/sync-agent-rules.py [--dry-run] [--verbose]

Idempotent: safe to run multiple times with identical results.
"""

import argparse
import json
import os
import re
import sys
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parent.parent.parent
CONTEXT_INDEX = PROJECT_ROOT / ".context" / "index.json"
SKILLS_DIR = PROJECT_ROOT / ".agents-shared" / "skills"

SYNC_TARGETS = {
    "cursor_context": PROJECT_ROOT / ".cursor" / "rules" / "context-system.mdc",
    "cursor_skills": PROJECT_ROOT / ".cursor" / "rules" / "skills-sync.mdc",
    "codex_instructions": PROJECT_ROOT / ".codex" / "instructions.md",
}

BEGIN_MARKER = "<!-- BEGIN:GENERATED:{section} -->"
END_MARKER = "<!-- END:GENERATED:{section} -->"


def load_context_index():
    """Load .context/index.json and return entries list."""
    if not CONTEXT_INDEX.exists():
        print(f"WARNING: {CONTEXT_INDEX} not found, skipping context sync",
              file=sys.stderr)
        return []

    with open(CONTEXT_INDEX, "r", encoding="utf-8") as f:
        data = json.load(f)

    return data.get("entries", [])


def load_skills_list():
    """Scan .agents-shared/skills/ for *.skill.md files and extract metadata."""
    skills = []
    if not SKILLS_DIR.exists():
        print(f"WARNING: {SKILLS_DIR} not found, skipping skills sync",
              file=sys.stderr)
        return skills

    for skill_file in sorted(SKILLS_DIR.glob("*.skill.md")):
        name = skill_file.stem.replace(".skill", "")
        description = ""
        category = ""

        content = skill_file.read_text(encoding="utf-8")
        if content.startswith("---"):
            end = content.find("---", 3)
            if end != -1:
                frontmatter = content[3:end]
                for line in frontmatter.strip().splitlines():
                    if line.startswith("description:"):
                        description = line.split(":", 1)[1].strip().strip("\"'")
                    elif line.startswith("category:"):
                        category = line.split(":", 1)[1].strip().strip("\"'")

        skills.append({
            "name": name,
            "file": f"{skill_file.name}",
            "description": description,
            "category": category,
        })

    return skills


def generate_context_inventory(entries):
    """Generate markdown table of all context entries grouped by domain/layer."""
    if not entries:
        return "_No context entries found. Run `./Scripts/context/add-context.sh` to create one._\n"

    groups = {}
    for entry in entries:
        domain = entry.get("domain", "unknown")
        layer = entry.get("layer", "unknown")
        key = f"{domain}/{layer}"
        if key not in groups:
            groups[key] = []
        groups[key].append(entry)

    lines = []
    for key in sorted(groups.keys()):
        domain, layer = key.split("/")
        lines.append(f"### {domain.title()} / {layer.title()} Layer\n")
        lines.append("| ID | Title | File | Key Triggers |")
        lines.append("|----|-------|------|-------------|")

        for entry in sorted(groups[key], key=lambda e: e["id"]):
            entry_id = entry["id"]
            title = entry.get("title", "")
            path = entry.get("path", "")
            triggers = entry.get("triggers", [])
            trigger_str = ", ".join(triggers[:6])
            if len(triggers) > 6:
                trigger_str += ", ..."
            lines.append(f"| {entry_id} | {title} | `{path}` | {trigger_str} |")

        lines.append("")

    total = len(entries)
    lines.append(f"**Total: {total} entries**\n")

    return "\n".join(lines)


def generate_skills_table(skills):
    """Generate markdown table of all available skills."""
    if not skills:
        return "_No skills found._\n"

    categorized = {}
    for skill in skills:
        cat = skill["category"] or "uncategorized"
        if cat not in categorized:
            categorized[cat] = []
        categorized[cat].append(skill)

    category_labels = {
        "strategic": "Strategic Skills (for complex tasks)",
        "analysis": "Analysis Skills (for debugging)",
        "generation": "Generation Skills (for creating code)",
        "knowledge-management": "Knowledge Management Skills",
        "uncategorized": "Other Skills",
    }

    lines = []
    for cat in ["strategic", "analysis", "generation", "knowledge-management", "uncategorized"]:
        if cat not in categorized:
            continue

        label = category_labels.get(cat, cat.title())
        lines.append(f"### {label}\n")
        lines.append("| Skill | File | Description |")
        lines.append("|-------|------|-------------|")

        for skill in sorted(categorized[cat], key=lambda s: s["name"]):
            lines.append(f"| {skill['name']} | `{skill['file']}` | {skill['description']} |")

        lines.append("")

    total = len(skills)
    lines.append(f"**Total: {total} skills**\n")

    return "\n".join(lines)


def replace_generated_section(content, section_name, new_content):
    """Replace content between BEGIN/END markers for a named section."""
    begin = BEGIN_MARKER.format(section=section_name)
    end = END_MARKER.format(section=section_name)

    pattern = re.compile(
        re.escape(begin) + r".*?" + re.escape(end),
        re.DOTALL
    )

    replacement = f"{begin}\n{new_content}\n{end}"

    if pattern.search(content):
        return pattern.sub(replacement, content)
    else:
        print(f"  WARNING: Markers for [{section_name}] not found, appending",
              file=sys.stderr)
        return content + f"\n{replacement}\n"


def sync_file(filepath, sections, dry_run=False, verbose=False):
    """Sync one file by replacing all its generated sections."""
    if not filepath.exists():
        print(f"  SKIP: {filepath.relative_to(PROJECT_ROOT)} (file not found)")
        return False

    original = filepath.read_text(encoding="utf-8")
    updated = original

    for section_name, content in sections.items():
        updated = replace_generated_section(updated, section_name, content)

    if updated == original:
        if verbose:
            print(f"  OK: {filepath.relative_to(PROJECT_ROOT)} (no changes)")
        return False

    if dry_run:
        print(f"  WOULD UPDATE: {filepath.relative_to(PROJECT_ROOT)}")
        return True

    filepath.write_text(updated, encoding="utf-8")
    print(f"  UPDATED: {filepath.relative_to(PROJECT_ROOT)}")
    return True


def main():
    parser = argparse.ArgumentParser(description="Sync agent rule files from shared sources")
    parser.add_argument("--dry-run", action="store_true", help="Show what would change without writing")
    parser.add_argument("--verbose", action="store_true", help="Show unchanged files too")
    args = parser.parse_args()

    print("=== Agent Rules Sync ===")
    print(f"Project root: {PROJECT_ROOT}")

    entries = load_context_index()
    print(f"Context entries: {len(entries)}")

    skills = load_skills_list()
    print(f"Skills: {len(skills)}")

    context_inventory = generate_context_inventory(entries)
    skills_table = generate_skills_table(skills)

    changes = 0

    if sync_file(SYNC_TARGETS["cursor_context"],
                 {"CONTEXT_INVENTORY": context_inventory},
                 dry_run=args.dry_run, verbose=args.verbose):
        changes += 1

    if sync_file(SYNC_TARGETS["cursor_skills"],
                 {"SKILLS_LIST": skills_table},
                 dry_run=args.dry_run, verbose=args.verbose):
        changes += 1

    if sync_file(SYNC_TARGETS["codex_instructions"],
                 {"CONTEXT_INVENTORY": context_inventory,
                  "SKILLS_LIST": skills_table},
                 dry_run=args.dry_run, verbose=args.verbose):
        changes += 1

    print(f"\nSync complete: {changes} file(s) {'would be ' if args.dry_run else ''}updated")

    return 0


if __name__ == "__main__":
    sys.exit(main())
