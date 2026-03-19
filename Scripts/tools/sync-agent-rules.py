#!/usr/bin/env python3
"""Synchronize agent rule files from shared sources of truth.

Reads .context/index.json, .agents-shared/skills/, and
.agents-shared/rules/hard-rules.md to regenerate marker-delimited
sections in agent-specific rule files across Claude, Cursor, and Codex.

This script is the SINGLE mechanism for keeping agent configs in sync.
It should be called after any of these changes:
  - New .context/ entry added (via add-context.sh)
  - .context/index.json regenerated (via generate-context-index.py)
  - New skill added to .agents-shared/skills/
  - Skill file modified
  - Hard rules modified in .agents-shared/rules/hard-rules.md

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
CLAUDE_SKILLS_DIR = PROJECT_ROOT / ".claude" / "skills"
HARD_RULES_FILE = PROJECT_ROOT / ".agents-shared" / "rules" / "hard-rules.md"
DIR_PLAYBOOKS_FILE = PROJECT_ROOT / ".agents-shared" / "directory-playbooks.json"
TOOLS_REGISTRY_FILE = PROJECT_ROOT / ".agents-shared" / "tools-registry.json"

SYNC_TARGETS = {
    "cursor_context": PROJECT_ROOT / ".cursor" / "rules" / "context-system.mdc",
    "cursor_skills": PROJECT_ROOT / ".cursor" / "rules" / "skills-sync.mdc",
    "cursor_swift": PROJECT_ROOT / ".cursor" / "rules" / "sources-swift.mdc",
    "cursor_scripts": PROJECT_ROOT / ".cursor" / "rules" / "scripts-directory.mdc",
    "codex_instructions": PROJECT_ROOT / ".codex" / "instructions.md",
    "claude_context": PROJECT_ROOT / ".claude" / "rules" / "context-system.md",
    "claude_skills": PROJECT_ROOT / ".claude" / "rules" / "skills-sync.md",
    "claude_hard_rules": PROJECT_ROOT / ".claude" / "rules" / "hard-rules.md",
    "gemini_config": PROJECT_ROOT / "GEMINI.md",
    "opencode_config": PROJECT_ROOT / "OPENCODE.md",
    "skills_readme": PROJECT_ROOT / ".agents-shared" / "skills" / "README.md",
}

BEGIN_MARKER = "<!-- BEGIN:GENERATED:{section} -->"
END_MARKER = "<!-- END:GENERATED:{section} -->"


def load_index_data():
    """Load full .context/index.json and return the parsed dict."""
    if not CONTEXT_INDEX.exists():
        print(
            f"WARNING: {CONTEXT_INDEX} not found, skipping context sync",
            file=sys.stderr,
        )
        return {}
    with open(CONTEXT_INDEX, "r", encoding="utf-8") as f:
        return json.load(f)


def load_context_index():
    """Load .context/index.json and return entries list."""
    return load_index_data().get("entries", [])


def load_skills_list():
    """Scan .agents-shared/skills/ for *.skill.md files and extract metadata."""
    skills = []
    if not SKILLS_DIR.exists():
        print(f"WARNING: {SKILLS_DIR} not found, skipping skills sync", file=sys.stderr)
        return skills

    for skill_file in sorted(SKILLS_DIR.glob("*.skill.md")):
        name = skill_file.stem.replace(".skill", "")
        description = ""
        category = ""

        quick_reference = ""

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
                    elif line.startswith("quick_reference:"):
                        quick_reference = line.split(":", 1)[1].strip().strip("\"'")

        skills.append(
            {
                "name": name,
                "file": f"{skill_file.name}",
                "description": description,
                "category": category,
                "quick_reference": quick_reference,
            }
        )

    return skills


def load_hard_rules():
    """Load .agents-shared/rules/hard-rules.md and extract sections by heading.

    Returns a dict mapping section keys to their markdown content:
      HARD_RULES_SWIFT, HARD_RULES_UIKIT, HARD_RULES_NEVERDO,
      HARD_RULES_SCRIPT, HARD_RULES_ARCHITECTURE
    """
    if not HARD_RULES_FILE.exists():
        print(
            f"WARNING: {HARD_RULES_FILE} not found, skipping hard rules sync",
            file=sys.stderr,
        )
        return {}

    content = HARD_RULES_FILE.read_text(encoding="utf-8")

    section_map = {
        "## Swift Hard Rules": "HARD_RULES_SWIFT",
        "## UIKit Hard Rules": "HARD_RULES_UIKIT",
        "## AI NEVER-DO List": "HARD_RULES_NEVERDO",
        "## Script Hard Rules": "HARD_RULES_SCRIPT",
        "## Architecture": "HARD_RULES_ARCHITECTURE",
    }

    headings = list(section_map.keys())
    result = {}

    for i, heading in enumerate(headings):
        start = content.find(heading)
        if start == -1:
            continue

        body_start = content.index("\n", start) + 1

        if i + 1 < len(headings):
            next_start = content.find(headings[i + 1])
            if next_start == -1:
                body = content[body_start:]
            else:
                body = content[body_start:next_start]
        else:
            body = content[body_start:]

        result[section_map[heading]] = body.strip() + "\n"

    return result


def load_directory_playbooks():
    """Load .agents-shared/directory-playbooks.json mapping."""
    if not DIR_PLAYBOOKS_FILE.exists():
        print(
            f"WARNING: {DIR_PLAYBOOKS_FILE} not found, skipping directory playbooks",
            file=sys.stderr,
        )
        return {}
    with open(DIR_PLAYBOOKS_FILE, "r", encoding="utf-8") as f:
        data = json.load(f)
    return {k: v for k, v in data.items() if not k.startswith("_")}


def generate_directory_playbooks(dir_map, entries):
    """Generate a DIRECTORY_PLAYBOOKS section from the mapping + index metadata."""
    if not dir_map:
        return "_No directory playbooks configured._\n"

    entry_lookup = {e["id"]: e for e in entries}

    lines = []
    for directory in sorted(dir_map.keys()):
        ids = dir_map[directory]
        lines.append(f"### When working in `{directory}`\n")
        lines.append("| Playbook | Title | File |")
        lines.append("|----------|-------|------|")
        for pid in ids:
            entry = entry_lookup.get(pid)
            if entry:
                title = entry.get("title", "")
                path = entry.get("path", "")
                lines.append(f"| {pid} | {title} | `{path}` |")
            else:
                lines.append(f"| {pid} | _(not found in index.json)_ | |")
        lines.append("")

    return "\n".join(lines)


def load_tools_registry():
    """Load .agents-shared/tools-registry.json (tools + makefile_targets)."""
    if not TOOLS_REGISTRY_FILE.exists():
        print(
            f"WARNING: {TOOLS_REGISTRY_FILE} not found, skipping tools sync",
            file=sys.stderr,
        )
        return [], []
    with open(TOOLS_REGISTRY_FILE, "r", encoding="utf-8") as f:
        data = json.load(f)
    return data.get("tools", []), data.get("makefile_targets", [])


def generate_tools_available(tools):
    """Generate a markdown table of available tools."""
    if not tools:
        return "_No tools registered._\n"

    lines = [
        "| Tool | Description | Usage |",
        "|------|-------------|-------|",
    ]
    for t in sorted(tools, key=lambda x: x["name"]):
        lines.append(f"| `{t['name']}` | {t['description']} | `{t['usage']}` |")

    lines.append("")
    lines.append(f"**Total: {len(tools)} tools**\n")
    return "\n".join(lines)


def generate_makefile_targets(targets):
    """Generate a markdown table of Makefile targets."""
    if not targets:
        return "_No Makefile targets registered._\n"

    lines = [
        "| Target | Description |",
        "|--------|-------------|",
    ]
    for t in targets:
        lines.append(f"| `{t['name']}` | {t['description']} |")

    lines.append("")
    return "\n".join(lines)


def generate_skill_guides(skills):
    """Generate condensed skill guides from quick_reference frontmatter."""
    guided = [s for s in skills if s.get("quick_reference")]
    if not guided:
        return "_No skills have quick_reference guides yet._\n"

    lines = []
    for skill in sorted(guided, key=lambda s: s["name"]):
        lines.append(f"### {skill['name'].replace('-', ' ').title()}\n")
        lines.append(f"{skill['quick_reference']}\n")
        lines.append(f"**Full Skill**: `.agents-shared/skills/{skill['file']}`\n")

    return "\n".join(lines)


def generate_keyword_domain_map(entries, index_data):
    """Generate keyword→domain mapping table from index tags.

    Only includes domains that have at least one entry (count > 0).
    Uses the 'tags' field (short, human-readable terms) rather than the
    'triggers' field (full error phrases) so the table stays scannable.
    """
    domains_info = index_data.get("domains", {})
    active_domains = sorted(
        d for d, info in domains_info.items() if info.get("count", 0) > 0
    )

    if not active_domains:
        return "_No active domains._\n"

    # Collect unique tags per domain preserving insertion order
    domain_tags: dict = {d: [] for d in active_domains}
    seen_per_domain: dict = {d: set() for d in active_domains}

    for entry in entries:
        domain = entry.get("domain", "")
        if domain not in domain_tags:
            continue
        for tag in entry.get("tags", []):
            tag_lower = tag.lower()
            if tag_lower not in seen_per_domain[domain]:
                seen_per_domain[domain].add(tag_lower)
                domain_tags[domain].append(tag)

    lines = []
    lines.append("| Keywords | Domain |")
    lines.append("|----------|--------|")
    for domain in active_domains:
        tags = domain_tags.get(domain, [])
        shown = tags[:7]
        kw_str = ", ".join(shown)
        if len(tags) > 7:
            kw_str += ", ..."
        lines.append(f"| {kw_str} | `{domain}` |")

    lines.append("")
    lines.append(
        "> Auto-generated from `.context/index.json` tags. "
        "Only domains with entries are listed."
    )

    return "\n".join(lines) + "\n"


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
    for cat in [
        "strategic",
        "analysis",
        "generation",
        "knowledge-management",
        "uncategorized",
    ]:
        if cat not in categorized:
            continue

        label = category_labels.get(cat, cat.title())
        lines.append(f"### {label}\n")
        lines.append("| Skill | File | Description |")
        lines.append("|-------|------|-------------|")

        for skill in sorted(categorized[cat], key=lambda s: s["name"]):
            lines.append(
                f"| {skill['name']} | `{skill['file']}` | {skill['description']} |"
            )

        lines.append("")

    total = len(skills)
    lines.append(f"**Total: {total} skills**\n")

    return "\n".join(lines)


def replace_generated_section(content, section_name, new_content):
    """Replace content between BEGIN/END markers for a named section."""
    begin = BEGIN_MARKER.format(section=section_name)
    end = END_MARKER.format(section=section_name)

    pattern = re.compile(re.escape(begin) + r".*?" + re.escape(end), re.DOTALL)

    replacement = f"{begin}\n{new_content}\n{end}"

    if pattern.search(content):
        return pattern.sub(replacement, content)
    else:
        print(
            f"  WARNING: Markers for [{section_name}] not found, appending",
            file=sys.stderr,
        )
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


def sync_skills_mirror(dry_run=False, verbose=False):
    """Sync skill files between .agents-shared/skills/ and .claude/skills/.

    SSOT: .agents-shared/skills/ is the source of truth.
    .claude/skills/ is a mirror copy for Claude Code's progressive loading.
    """
    if not SKILLS_DIR.exists():
        print("  SKIP: .agents-shared/skills/ not found")
        return 0
    if not CLAUDE_SKILLS_DIR.exists():
        CLAUDE_SKILLS_DIR.mkdir(parents=True, exist_ok=True)
        print(f"  CREATED: {CLAUDE_SKILLS_DIR.relative_to(PROJECT_ROOT)}/")

    changes = 0
    shared_skills = {f.name for f in SKILLS_DIR.glob("*.skill.md")}
    claude_skills = {f.name for f in CLAUDE_SKILLS_DIR.glob("*.skill.md")}

    # Copy new/updated skills from shared → claude
    for name in sorted(shared_skills):
        src = SKILLS_DIR / name
        dst = CLAUDE_SKILLS_DIR / name
        if not dst.exists():
            if dry_run:
                print(f"  WOULD COPY: {name} → .claude/skills/")
            else:
                import shutil

                shutil.copy2(src, dst)
                print(f"  COPIED: {name} → .claude/skills/")
            changes += 1
        else:
            src_content = src.read_text(encoding="utf-8")
            dst_content = dst.read_text(encoding="utf-8")
            if src_content != dst_content:
                if dry_run:
                    print(f"  WOULD UPDATE: .claude/skills/{name}")
                else:
                    dst.write_text(src_content, encoding="utf-8")
                    print(f"  UPDATED: .claude/skills/{name}")
                changes += 1
            elif verbose:
                print(f"  OK: {name} (identical)")

    # Remove orphaned skills in claude that no longer exist in shared
    orphans = claude_skills - shared_skills
    for name in sorted(orphans):
        orphan_path = CLAUDE_SKILLS_DIR / name
        if dry_run:
            print(f"  WOULD REMOVE: .claude/skills/{name} (orphaned)")
        else:
            orphan_path.unlink()
            print(f"  REMOVED: .claude/skills/{name} (orphaned)")
        changes += 1

    return changes


def main():
    parser = argparse.ArgumentParser(
        description="Sync agent rule files from shared sources"
    )
    parser.add_argument(
        "--dry-run", action="store_true", help="Show what would change without writing"
    )
    parser.add_argument(
        "--verbose", action="store_true", help="Show unchanged files too"
    )
    args = parser.parse_args()

    print("=== Agent Rules Sync ===")
    print(f"Project root: {PROJECT_ROOT}")

    index_data = load_index_data()
    entries = index_data.get("entries", [])
    print(f"Context entries: {len(entries)}")

    skills = load_skills_list()
    print(f"Skills: {len(skills)}")

    hard_rules = load_hard_rules()
    print(f"Hard rule sections: {len(hard_rules)}")

    dir_playbooks_map = load_directory_playbooks()
    print(f"Directory playbook mappings: {len(dir_playbooks_map)}")

    tools, make_targets = load_tools_registry()
    print(f"Tools: {len(tools)}, Makefile targets: {len(make_targets)}")

    context_inventory = generate_context_inventory(entries)
    keyword_domain_map = generate_keyword_domain_map(entries, index_data)
    skills_table = generate_skills_table(skills)
    skill_guides = generate_skill_guides(skills)
    dir_playbooks = generate_directory_playbooks(dir_playbooks_map, entries)
    tools_available = generate_tools_available(tools)
    makefile_targets = generate_makefile_targets(make_targets)

    changes = 0

    # Cursor: context + keyword map + directory playbooks + tools
    if sync_file(
        SYNC_TARGETS["cursor_context"],
        {
            "CONTEXT_INVENTORY": context_inventory,
            "KEYWORD_DOMAIN_MAP": keyword_domain_map,
            "DIRECTORY_PLAYBOOKS": dir_playbooks,
            "TOOLS_AVAILABLE": tools_available,
            "MAKEFILE_TARGETS": makefile_targets,
        },
        dry_run=args.dry_run,
        verbose=args.verbose,
    ):
        changes += 1

    if sync_file(
        SYNC_TARGETS["cursor_skills"],
        {"SKILLS_LIST": skills_table, "SKILL_GUIDES": skill_guides},
        dry_run=args.dry_run,
        verbose=args.verbose,
    ):
        changes += 1

    # Cursor: hard rules (swift/uikit/neverdo in sources-swift, script in scripts-directory)
    cursor_swift_sections = {}
    for key in (
        "HARD_RULES_SWIFT",
        "HARD_RULES_UIKIT",
        "HARD_RULES_NEVERDO",
        "HARD_RULES_ARCHITECTURE",
    ):
        if key in hard_rules:
            cursor_swift_sections[key] = hard_rules[key]
    if cursor_swift_sections:
        if sync_file(
            SYNC_TARGETS["cursor_swift"],
            cursor_swift_sections,
            dry_run=args.dry_run,
            verbose=args.verbose,
        ):
            changes += 1

    if "HARD_RULES_SCRIPT" in hard_rules:
        if sync_file(
            SYNC_TARGETS["cursor_scripts"],
            {"HARD_RULES_SCRIPT": hard_rules["HARD_RULES_SCRIPT"]},
            dry_run=args.dry_run,
            verbose=args.verbose,
        ):
            changes += 1

    # Codex: everything in one file
    codex_sections = {
        "CONTEXT_INVENTORY": context_inventory,
        "KEYWORD_DOMAIN_MAP": keyword_domain_map,
        "SKILLS_LIST": skills_table,
        "SKILL_GUIDES": skill_guides,
        "DIRECTORY_PLAYBOOKS": dir_playbooks,
        "TOOLS_AVAILABLE": tools_available,
        "MAKEFILE_TARGETS": makefile_targets,
    }
    codex_sections.update(hard_rules)
    if sync_file(
        SYNC_TARGETS["codex_instructions"],
        codex_sections,
        dry_run=args.dry_run,
        verbose=args.verbose,
    ):
        changes += 1

    # Claude: context + keyword map + directory playbooks + tools
    if sync_file(
        SYNC_TARGETS["claude_context"],
        {
            "CONTEXT_INVENTORY": context_inventory,
            "KEYWORD_DOMAIN_MAP": keyword_domain_map,
            "DIRECTORY_PLAYBOOKS": dir_playbooks,
            "TOOLS_AVAILABLE": tools_available,
            "MAKEFILE_TARGETS": makefile_targets,
        },
        dry_run=args.dry_run,
        verbose=args.verbose,
    ):
        changes += 1

    if sync_file(
        SYNC_TARGETS["claude_skills"],
        {"SKILLS_LIST": skills_table, "SKILL_GUIDES": skill_guides},
        dry_run=args.dry_run,
        verbose=args.verbose,
    ):
        changes += 1

    # Claude: hard rules (all sections in one file)
    if hard_rules:
        if sync_file(
            SYNC_TARGETS["claude_hard_rules"],
            hard_rules,
            dry_run=args.dry_run,
            verbose=args.verbose,
        ):
            changes += 1

    # Gemini: everything in one file (GEMINI.md)
    gemini_sections = {
        "CONTEXT_INVENTORY": context_inventory,
        "KEYWORD_DOMAIN_MAP": keyword_domain_map,
        "SKILLS_LIST": skills_table,
        "SKILL_GUIDES": skill_guides,
        "DIRECTORY_PLAYBOOKS": dir_playbooks,
        "TOOLS_AVAILABLE": tools_available,
        "MAKEFILE_TARGETS": makefile_targets,
    }
    gemini_sections.update(hard_rules)
    if sync_file(
        SYNC_TARGETS["gemini_config"],
        gemini_sections,
        dry_run=args.dry_run,
        verbose=args.verbose,
    ):
        changes += 1

    # OpenCode: everything in one file (OPENCODE.md)
    opencode_sections = {
        "CONTEXT_INVENTORY": context_inventory,
        "KEYWORD_DOMAIN_MAP": keyword_domain_map,
        "SKILLS_LIST": skills_table,
        "SKILL_GUIDES": skill_guides,
        "DIRECTORY_PLAYBOOKS": dir_playbooks,
        "TOOLS_AVAILABLE": tools_available,
        "MAKEFILE_TARGETS": makefile_targets,
    }
    opencode_sections.update(hard_rules)
    if sync_file(
        SYNC_TARGETS["opencode_config"],
        opencode_sections,
        dry_run=args.dry_run,
        verbose=args.verbose,
    ):
        changes += 1

    # Shared skills README
    if sync_file(
        SYNC_TARGETS["skills_readme"],
        {"SKILLS_LIST": skills_table},
        dry_run=args.dry_run,
        verbose=args.verbose,
    ):
        changes += 1

    # Skills mirror: .agents-shared/skills/ → .claude/skills/
    print("\n--- Skills Mirror ---")
    mirror_changes = sync_skills_mirror(dry_run=args.dry_run, verbose=args.verbose)
    if mirror_changes == 0:
        print("  Skills mirror is up to date")
    changes += mirror_changes

    print(
        f"\nSync complete: {changes} file(s) {'would be ' if args.dry_run else ''}updated"
    )

    return 0


if __name__ == "__main__":
    sys.exit(main())
