# Claude Code adapter — Discourse Video Hub

Canonical policy remains in root `AGENTS.md` and `docs/ai/EFFORT_ROUTER.md`.
These are thin runtime adapters. Keep repo business invariants out of them.
If a Claude Code version does not support a frontmatter key, remove only that
unsupported runtime key; preserve the tier policy.

Claude is the default builder role. Builder output is `READY`, not approval or merge authorization.
