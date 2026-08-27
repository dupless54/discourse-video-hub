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

## Delivery roles
- Claude: builder; returns `READY` with exact paths/evidence, never self-approval.
- Codex: independent diff-first reviewer; returns `APPROVE` or `REQUEST_CHANGES`.
- Gemini: mandatory final exact-head verifier; returns `APPROVE`, `REJECT` or `NEEDS_HUMAN`.
- Any unresolved disagreement requires human arbitration. None of these roles grants merge authority.
