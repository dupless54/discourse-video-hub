# Claude Code adapter — Discourse Video Hub

Canonical policy remains in root `AGENTS.md` and `docs/ai/EFFORT_ROUTER.md`.
These are thin runtime adapters. Keep repo business invariants out of them.
If a Claude Code version does not support a frontmatter key, remove only that
unsupported runtime key; preserve the tier policy.

Claude may implement, inspect, review, or repair tasks according to the selected effort tier. No Claude `READY` or approval state is required for merge; merge eligibility is defined only by the CI-only gate in root `AGENTS.md`.
