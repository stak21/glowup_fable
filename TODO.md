# Skill Journal — deferred features

1. **Complexity/trust meter** — relaxed/standard/caution tiers per pack, badges on pack + routine cards, disclaimer cards for caution domains, extra "AI-generated" framing for non-bundled packs. Re-add as optional `complexity`/`disclaimer` schema fields (non-breaking for v1 packs).
2. **Runtime custom generation ("describe your own routine")** — serverless proxy (e.g. Cloudflare Worker) holding the Anthropic key; `claude-opus-4-8` + structured outputs on the exact DomainPack schema (packs/PROMPT.md is the system prompt); per-device rate limit; refusal → "this topic needs a professional" state; generated packs saved to `Documents/Packs/` (PackStore already loads that folder); disclosure copy in About + the Explore entry point. The app never embeds an API key.
3. Shop/affiliate integration for pack products (GlowUp's Affiliate helper is the reference).
4. Pack sharing/export; iCloud sync.
5. A skincare pack derived from GlowUp content.
6. Final app name / icon — "Skill Journal" is the working name; bundle id locked as com.takado.SkillJournal unless changed before first TestFlight.
