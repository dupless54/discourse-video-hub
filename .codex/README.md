# Codex adapter templates — Discourse Video Hub

Canonical routing lives in `AGENTS.md` and `docs/ai/EFFORT_ROUTER.md`.
Model IDs and exact config fields may vary by runtime/account, so the TOML files
use placeholders. Replace them only with model IDs supported by the active runtime.
If native per-subagent switching is unavailable, apply the tier at orchestrator/session level.

Codex may implement, inspect, review, or repair tasks according to the selected effort tier. No Codex `APPROVE` state is required for merge; merge eligibility is defined only by the CI-only gate in root `AGENTS.md`.
