#!/usr/bin/env python3
"""Validate SkillJournal/Pack-*.json against the DomainPack v1 schema.

Checks field presence/types, enum values, day ranges, cadence kinds, and
referential integrity (categoryIDs, coreCategoryIDs, photoAreaIDs, productIDs,
quiz templateVotes keys). Exits non-zero on any failure.
"""

import json
import sys
from pathlib import Path

THEMES = {"gold", "lavender", "rose", "coral", "green"}
CADENCE_KINDS = {"daily", "everyOtherDay", "days"}

errors = []


def err(pack_id, msg):
    errors.append(f"[{pack_id}] {msg}")


def check_cadence(pack_id, where, cadence):
    if not isinstance(cadence, dict):
        err(pack_id, f"{where}: cadence must be an object")
        return
    kind = cadence.get("kind")
    if kind not in CADENCE_KINDS:
        err(pack_id, f"{where}: bad cadence kind {kind!r}")
    days = cadence.get("days")
    if kind == "days":
        if not isinstance(days, list) or not days:
            err(pack_id, f"{where}: kind 'days' needs a non-empty days array")
        elif any(not isinstance(d, int) or d < 0 or d > 6 for d in days):
            err(pack_id, f"{where}: days out of 0–6 range: {days}")
    elif days is not None:
        err(pack_id, f"{where}: days present but kind is {kind!r}")


def validate(path):
    pack = json.loads(path.read_text())
    pid = pack.get("id", path.name)

    if pack.get("schemaVersion") != 1:
        err(pid, f"schemaVersion must be 1, got {pack.get('schemaVersion')!r}")
    for field in ("id", "name", "emoji", "tagline", "accentTheme"):
        if not isinstance(pack.get(field), str) or not pack[field]:
            err(pid, f"missing/empty string field {field!r}")
    if pack.get("accentTheme") not in THEMES:
        err(pid, f"accentTheme {pack.get('accentTheme')!r} not in {sorted(THEMES)}")
    if f"Pack-{pack.get('id')}.json" != path.name:
        err(pid, f"file {path.name} doesn't match id {pack.get('id')!r}")

    categories = pack.get("categories") or []
    cat_ids = [c.get("id") for c in categories]
    if not categories:
        err(pid, "categories must be non-empty")
    if len(set(cat_ids)) != len(cat_ids):
        err(pid, f"duplicate category ids: {cat_ids}")
    for c in categories:
        for field in ("id", "name", "emoji"):
            if not isinstance(c.get(field), str) or not c[field]:
                err(pid, f"category {c.get('id')!r}: missing {field!r}")
        if not isinstance(c.get("sortRank"), int):
            err(pid, f"category {c.get('id')!r}: sortRank must be an int")
    ranks = [c.get("sortRank") for c in categories]
    if len(set(ranks)) != len(ranks):
        err(pid, f"duplicate sortRanks: {ranks}")
    cat_set = set(cat_ids)

    core = pack.get("coreCategoryIDs")
    if not isinstance(core, list) or not core:
        err(pid, "coreCategoryIDs must be a non-empty array")
        core = []
    for cid in core:
        if cid not in cat_set:
            err(pid, f"coreCategoryIDs references unknown category {cid!r}")

    for i, rule in enumerate(pack.get("waitRules") or []):
        if not isinstance(rule.get("minutes"), int) or not 1 <= rule["minutes"] <= 30:
            err(pid, f"waitRules[{i}]: minutes must be int 1–30")
        if rule.get("categoryID") is not None and rule["categoryID"] not in cat_set:
            err(pid, f"waitRules[{i}]: unknown categoryID {rule['categoryID']!r}")
        if rule.get("categoryID") is None and rule.get("keyword") is None:
            err(pid, f"waitRules[{i}]: needs a categoryID or a keyword")
    for i, rule in enumerate(pack.get("cadenceRules") or []):
        check_cadence(pid, f"cadenceRules[{i}]", rule.get("cadence"))
        if rule.get("categoryID") is not None and rule["categoryID"] not in cat_set:
            err(pid, f"cadenceRules[{i}]: unknown categoryID {rule['categoryID']!r}")
        if rule.get("categoryID") is None and rule.get("keyword") is None:
            err(pid, f"cadenceRules[{i}]: needs a categoryID or a keyword")

    area_ids = {a.get("id") for a in pack.get("photoAreas") or []}
    for a in pack.get("photoAreas") or []:
        for field in ("id", "title", "emoji"):
            if not isinstance(a.get(field), str) or not a[field]:
                err(pid, f"photoArea {a.get('id')!r}: missing {field!r}")

    product_ids = set()
    for p in pack.get("products") or []:
        for field in ("id", "name", "tag", "what", "why", "order"):
            if not isinstance(p.get(field), str) or not p[field]:
                err(pid, f"product {p.get('id')!r}: missing {field!r}")
        if p.get("categoryID") is not None and p["categoryID"] not in cat_set:
            err(pid, f"product {p.get('id')!r}: unknown categoryID {p['categoryID']!r}")
        product_ids.add(p.get("id"))

    templates = pack.get("templates") or []
    if not templates:
        err(pid, "templates must be non-empty")
    template_ids = set()
    for t in templates:
        tid = t.get("id")
        template_ids.add(tid)
        for field in ("id", "title", "blurb"):
            if not isinstance(t.get(field), str) or not t[field]:
                err(pid, f"template {tid!r}: missing {field!r}")
        routines = t.get("routines") or []
        if not routines:
            err(pid, f"template {tid!r}: routines must be non-empty")
        for r in routines:
            where = f"template {tid!r} routine {r.get('title')!r}"
            for field in ("title", "emoji", "theme"):
                if not isinstance(r.get(field), str) or not r[field]:
                    err(pid, f"{where}: missing {field!r}")
            if r.get("theme") not in THEMES:
                err(pid, f"{where}: bad theme {r.get('theme')!r}")
            days = r.get("days")
            if not isinstance(days, list) or not days:
                err(pid, f"{where}: days must be non-empty")
            elif any(not isinstance(d, int) or d < 0 or d > 6 for d in days):
                err(pid, f"{where}: days out of 0–6 range: {days}")
            if r.get("photoAreaID") is not None and r["photoAreaID"] not in area_ids:
                err(pid, f"{where}: unknown photoAreaID {r['photoAreaID']!r}")
            steps = r.get("steps") or []
            if not steps:
                err(pid, f"{where}: steps must be non-empty")
            for s in steps:
                sw = f"{where} step {s.get('label')!r}"
                if not isinstance(s.get("label"), str) or not s["label"]:
                    err(pid, f"{sw}: missing label")
                if s.get("categoryID") is not None and s["categoryID"] not in cat_set:
                    err(pid, f"{sw}: unknown categoryID {s['categoryID']!r}")
                if s.get("productID") is not None and s["productID"] not in product_ids:
                    err(pid, f"{sw}: unknown productID {s['productID']!r}")
                if s.get("waitMinutes") is not None and (
                    not isinstance(s["waitMinutes"], int) or not 1 <= s["waitMinutes"] <= 30
                ):
                    err(pid, f"{sw}: waitMinutes must be int 1–30")
                if s.get("cadence") is not None:
                    check_cadence(pid, sw, s["cadence"])

    quiz = pack.get("quiz")
    if quiz is not None:
        questions = quiz.get("questions") or []
        if not questions:
            err(pid, "quiz present but has no questions")
        for qi, q in enumerate(questions):
            if not isinstance(q.get("prompt"), str) or not q["prompt"]:
                err(pid, f"quiz[{qi}]: missing prompt")
            options = q.get("options") or []
            if len(options) < 2:
                err(pid, f"quiz[{qi}]: needs ≥2 options")
            for oi, o in enumerate(options):
                for field in ("emoji", "title"):
                    if not isinstance(o.get(field), str) or not o[field]:
                        err(pid, f"quiz[{qi}].options[{oi}]: missing {field!r}")
                votes = o.get("templateVotes")
                if not isinstance(votes, dict) or not votes:
                    err(pid, f"quiz[{qi}].options[{oi}]: templateVotes must be non-empty")
                    continue
                for tid, weight in votes.items():
                    if tid not in template_ids:
                        err(pid, f"quiz[{qi}].options[{oi}]: vote for unknown template {tid!r}")
                    if not isinstance(weight, int) or weight < 1:
                        err(pid, f"quiz[{qi}].options[{oi}]: weight for {tid!r} must be int ≥1")

    for page in pack.get("educationPages") or []:
        for field in ("title", "emoji", "body"):
            if not isinstance(page.get(field), str) or not page[field]:
                err(pid, f"education page {page.get('title')!r}: missing {field!r}")

    return pack


def main():
    root = Path(__file__).resolve().parent.parent
    paths = sorted((root / "SkillJournal").glob("Pack-*.json"))
    if not paths:
        print("No Pack-*.json files found", file=sys.stderr)
        return 1
    for path in paths:
        try:
            pack = validate(path)
            status = "FAIL" if any(e.startswith(f"[{pack.get('id')}]") for e in errors) else "ok"
            print(f"{path.name}: {status}")
        except json.JSONDecodeError as e:
            errors.append(f"[{path.name}] invalid JSON: {e}")
            print(f"{path.name}: FAIL (invalid JSON)")
    if errors:
        print("\n".join(errors), file=sys.stderr)
        return 1
    print(f"\n{len(paths)} packs valid ✓")
    return 0


if __name__ == "__main__":
    sys.exit(main())
