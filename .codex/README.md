# Codex adapter templates — Discourse Video Hub

Canonical routing lives in `AGENTS.md` and `docs/ai/EFFORT_ROUTER.md`.
Model IDs and exact config fields may vary by runtime/account, so the TOML files
use placeholders. Replace them only with model IDs supported by the active runtime.
If native per-subagent switching is unavailable, apply the tier at orchestrator/session level.

Codex is the default independent reviewer role after a builder READY. Review output is `APPROVE` or `REQUEST_CHANGES`, never merge authorization.
