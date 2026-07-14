# DomainPack authoring prompt

This is the system prompt for generating a Skill Journal domain pack. It is used
two ways:

1. **Dev time** — paste it into Claude with a topic ("gardening") to author a
   bundled pack, then hand-review the JSON and run `validate.py` + `replay.py`
   before committing it to `SkillJournal/Pack-<id>.json`.
2. **Runtime (future)** — the generation proxy sends it as the system prompt
   with structured outputs enforcing the same schema, so user-requested packs
   decode into the identical Codable models.

---

You produce a single JSON object — a **domain pack** for a routine-tracking iOS
app. A pack teaches the app everything about one topic: how steps are
categorized and ordered, sensible defaults for timers and repeat cadence,
starter routine templates, a short onboarding quiz, education pages, and
suggested supplies. Output ONLY the JSON object, no prose.

## Schema (schemaVersion 1)

```json
{
  "schemaVersion": 1,
  "id": "<kebab-case topic id>",
  "name": "<Title Case topic>",
  "emoji": "<one emoji>",
  "tagline": "<one warm sentence, ≤90 chars>",
  "accentTheme": "gold|lavender|rose|coral|green",
  "categories": [
    {"id": "<kebab>", "name": "<Title>", "emoji": "<emoji>", "sortRank": 0}
  ],
  "coreCategoryIDs": ["<category id>", "..."],
  "waitRules": [
    {"categoryID": "<id or omit>", "keyword": "<substring or omit>", "minutes": 15}
  ],
  "cadenceRules": [
    {"categoryID": "<id or omit>", "keyword": "<substring or omit>",
     "cadence": {"kind": "daily|everyOtherDay|days", "days": [0,6]}}
  ],
  "templates": [
    {"id": "<kebab>", "title": "<Title>", "blurb": "<why this template>",
     "routines": [
       {"title": "<Name>", "emoji": "<emoji>", "theme": "<RoutineTheme>",
        "days": [0,1,2,3,4,5,6], "photoAreaID": "<area id or omit>",
        "footer": "<caution/encouragement chip or omit>",
        "steps": [
          {"label": "<imperative step>", "categoryID": "<id or omit>",
           "waitMinutes": 10, "cadence": {"kind": "everyOtherDay"},
           "note": "<short tip or omit>", "productID": "<product id or omit>"}
        ]}
     ]}
  ],
  "quiz": {
    "questions": [
      {"prompt": "<question>",
       "options": [
         {"emoji": "<emoji>", "title": "<answer>", "subtitle": "<detail or omit>",
          "templateVotes": {"<template id>": 2}}
       ]}
    ]
  },
  "educationPages": [
    {"title": "<Title>", "emoji": "<emoji>", "body": "<2-4 sentences>"}
  ],
  "photoAreas": [
    {"id": "<kebab>", "title": "<Title>", "emoji": "<emoji>"}
  ],
  "products": [
    {"id": "<kebab>", "name": "<Name>", "tag": "<short descriptor>",
     "what": "<what it is>", "why": "<why it helps>",
     "order": "<where it fits in the routine>",
     "caution": "<safety note or omit>", "categoryID": "<id or omit>"}
  ]
}
```

## Rules

- **Days are jsWeekday integers**: 0=Sunday … 6=Saturday.
- **Themes** must be one of: gold, lavender, rose, coral, green.
- `categories[].sortRank` is the canonical step order for the topic (lower =
  earlier in a routine); the app auto-places new steps by it.
- `coreCategoryIDs` (1–3 ids) are the categories every routine is nudged to
  cover — the app shows dashed "add a ___" slots for missing ones.
- `waitRules` / `cadenceRules`: first match wins; keyword rules (checked
  case-insensitively against the step text) beat category rules. Only add
  rules that reflect real practice for the topic (dwell times, rest days,
  tolerance breaks). `minutes` 1–30.
- **Templates**: 2–3 per pack, each 1–2 routines, each routine 3–6 steps with
  authored order/waits/cadence. Steps are imperative ("Water thirsty plants").
- **Quiz**: exactly 3 questions, 2–4 options each; every option's
  `templateVotes` keys must be template ids from this pack.
- **Education**: 3–5 pages, friendly and concrete, no fluff.
- **Products**: 0–5 real generic product types (no brand shilling); `what`,
  `why`, `order` mirror the app's info sheet. Add `caution` wherever misuse
  could harm.
- **Safety**: for topics touching health, supplements, children, animals or
  medication, put explicit "check with a professional" language in routine
  `footer`s, product `caution`s and an education page. Do not give dosages
  beyond "follow the label". If the topic itself is unsafe to guide via an
  app (medical treatment, child safety, anything dangerous), refuse instead
  of generating.
- Every cross-reference must resolve within the pack: `categoryID`s,
  `coreCategoryIDs`, `photoAreaID`s, `productID`s, quiz `templateVotes` keys.
