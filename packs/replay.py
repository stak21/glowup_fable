#!/usr/bin/env python3
"""Replay SkillJournal's pack rule logic over every pack, in Python.

Re-implements three pieces of Swift logic 1:1 and exercises them against the
real pack JSON, so rule-table typos surface without a UI walkthrough:

1. DomainPack.defaultWaitMinutes / defaultCadence (Models.swift) — keyword
   rules (case-insensitive contains) win over pure-category rules, first
   match in array order.
2. RoutinePlacement.insertionIndex (Models.swift) — rank-anchored walk.
3. Store.draftRoutines omitCoreCategories — a routine omits core categories
   covered by a sibling routine in the same template.

For every template step it prints what the engine would derive for a
hand-added step with the same text/category, flags templates whose sibling
coverage produces omissions, and sanity-checks insertion order: inserting
each template's steps in authored order through insertionIndex must keep
categorized steps in non-decreasing rank order.
"""

import json
import sys
from pathlib import Path


def default_wait(pack, text, category_id):
    lowered = text.lower()
    for rule in pack.get("waitRules") or []:
        keyword = rule.get("keyword")
        if keyword is None or keyword.lower() not in lowered:
            continue
        if rule.get("categoryID") is not None and rule["categoryID"] != category_id:
            continue
        return rule["minutes"]
    for rule in pack.get("waitRules") or []:
        if rule.get("keyword") is None and rule.get("categoryID") == category_id:
            return rule["minutes"]
    return None


def default_cadence(pack, text, category_id):
    lowered = text.lower()
    for rule in pack.get("cadenceRules") or []:
        keyword = rule.get("keyword")
        if keyword is None or keyword.lower() not in lowered:
            continue
        if rule.get("categoryID") is not None and rule["categoryID"] != category_id:
            continue
        return rule["cadence"]
    for rule in pack.get("cadenceRules") or []:
        if rule.get("keyword") is None and rule.get("categoryID") == category_id:
            return rule["cadence"]
    return None


def rank(pack, category_id):
    for c in pack["categories"]:
        if c["id"] == category_id:
            return c["sortRank"]
    return None


def insertion_index(pack, category_id, steps):
    """steps: list of categoryID-or-None. Mirrors RoutinePlacement.insertionIndex."""
    new_rank = rank(pack, category_id) if category_id else None
    if new_rank is None:
        return len(steps)
    index = None
    for i, existing in enumerate(steps):
        existing_rank = rank(pack, existing) if existing else None
        if existing_rank is not None and existing_rank <= new_rank:
            index = i + 1
    if index is not None:
        return index
    return 0 if any(rank(pack, s) is not None for s in steps if s) else len(steps)


def main():
    root = Path(__file__).resolve().parent.parent
    failures = 0
    for path in sorted((root / "SkillJournal").glob("Pack-*.json")):
        pack = json.loads(path.read_text())
        print(f"\n=== {pack['id']} ===")

        for template in pack["templates"]:
            covered = [
                {s.get("categoryID") for s in r["steps"] if s.get("categoryID")}
                for r in template["routines"]
            ]
            core = set(pack["coreCategoryIDs"])
            for idx, routine in enumerate(template["routines"]):
                omit = set()
                for j, sibling in enumerate(covered):
                    if j != idx:
                        omit |= sibling
                omit -= covered[idx]
                omit &= core
                missing = [c for c in pack["coreCategoryIDs"]
                           if c not in covered[idx] and c not in omit]
                note = ""
                if omit:
                    note += f" omit={sorted(omit)}"
                if missing:
                    note += f" placeholders={missing}"
                print(f"  {template['id']} / {routine['title']}:{note or ' complete'}")

                # Insertion-order sanity: authored steps re-inserted through
                # insertionIndex must come out in non-decreasing rank order.
                placed = []
                for step in routine["steps"]:
                    cid = step.get("categoryID")
                    placed.insert(insertion_index(pack, cid, placed), cid)
                ranks = [rank(pack, c) for c in placed if c is not None]
                if ranks != sorted(ranks):
                    print(f"    ✗ insertion order broken: {placed} → ranks {ranks}")
                    failures += 1

                # What the engine would derive for a hand-added step with the
                # same text/category — surfaces which rules actually fire.
                for step in routine["steps"]:
                    text = step["label"]
                    cid = step.get("categoryID")
                    wait = default_wait(pack, text, cid)
                    cadence = default_cadence(pack, text, cid)
                    derived = []
                    if wait is not None:
                        derived.append(f"wait={wait}m")
                    if cadence is not None:
                        derived.append(f"cadence={cadence['kind']}"
                                       + (str(cadence.get("days")) if cadence.get("days") else ""))
                    authored = []
                    if step.get("waitMinutes") is not None:
                        authored.append(f"wait={step['waitMinutes']}m")
                    if step.get("cadence") is not None:
                        authored.append(f"cadence={step['cadence']['kind']}"
                                        + (str(step['cadence'].get("days")) if step['cadence'].get("days") else ""))
                    marker = "≠" if derived != authored and (derived or authored) else " "
                    print(f"    {marker} {text[:44]:<46} authored[{', '.join(authored) or '—'}]"
                          f" rules[{', '.join(derived) or '—'}]")

    print()
    if failures:
        print(f"{failures} insertion-order failure(s)", file=sys.stderr)
        return 1
    print("replay complete — insertion order consistent for all templates ✓")
    return 0


if __name__ == "__main__":
    sys.exit(main())
