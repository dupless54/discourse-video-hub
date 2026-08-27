# Version

Name: Discourse Video Hub Context
Version: v1.0.0
Base: Minimum Token Context v3
Snapshot date: 2026-08-27

Project adaptations:
- video -> Topic -> root Post ownership contract
- Discourse Reactions and core Nested Replies integration
- provider adapter and SSRF guardrails
- profile section/order model
- discovery ranking, privacy and abuse boundaries
- canonical watch page, crawler and VideoObject SEO contract
- Glimmer/FormKit/theme/mobile feed constraints
- Claude builder -> Codex reviewer -> Gemini verifier delivery gate

Preserved from v3:
- adaptive minimum context and T0-T3 effort routing
- source/tests authority
- exact-head CI discipline and `NO_CI != GREEN`
- explicit merge authorization and no test weakening
- no AI context inside Discourse compiled asset paths
