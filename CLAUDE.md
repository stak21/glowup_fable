Two SwiftUI apps live in this repo, sharing nothing but patterns:

- **Clearing/** + **Clearing.xcodeproj** — "GlowUp", the skincare routine tracker (iOS 17+). All UI follows the rose/blush palette in its Color extension.
- **SkillJournal/** + **SkillJournal.xcodeproj** — "Skill Journal", the pack-driven modular routine builder (iOS 17+). Domain content comes from Pack-*.json files (schema in packs/PROMPT.md); themes are chosen per pack/routine from the shared RoutineTheme palette.

Build with xcodebuild before declaring a task done — scheme `Clearing` or `SkillJournal` respectively. After editing any SkillJournal/Pack-*.json, run `python3 packs/validate.py` and `python3 packs/replay.py`.
