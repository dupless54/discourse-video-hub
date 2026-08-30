# Platform Adapters

`AGENTS.md` is canonical policy. Platform adapters contain runtime mechanics only.

| Tier | Purpose | Model class | Effort |
|---|---|---|---|
| T0 | Mechanical | cheapest capable | low |
| T1 | Routine implementation | balanced coding | medium |
| T2 | High-risk | strong reasoning | high |
| T3 | Exceptional | strongest available | highest justified |

Rules:
- Do not duplicate business invariants or current PR/CI state in adapters.
- Do not hard-code unsupported model IDs.
- If native switching is unavailable, preserve tier classification and apply it at orchestrator/session level.
- If native effort control is unavailable, preserve behavioral limits: narrow reads, bounded turns, targeted checks, explicit escalation.
- Claude, Codex, Gemini, ChatGPT, or other models may be used according to capability/effort needs; no model-specific READY/APPROVE/verification role is required.
- Merge eligibility comes only from the canonical CI-only gate in root `AGENTS.md`: latest exact-head required Discourse CI GREEN, scope valid, and no unresolved high-risk blocker.
