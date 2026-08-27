# Delivery Workflow

`Task packet -> Claude builder -> targeted validation -> PR -> exact-head CI -> Codex independent review -> Gemini final verification -> explicit user merge authorization`

## Gates
- Lock goal, allowed paths, acceptance, validation and risk before implementation.
- Claude builds and returns `READY` with exact changed paths and evidence; it does not self-approve.
- Cheap-first validation: syntax/static -> narrow specs -> plugin suite -> frontend QUnit/build -> broader/system only if justified.
- PR/CI evidence must match the latest exact head. A new commit invalidates all prior approvals and CI evidence.
- Codex independently reviews diff first, then touched symbols/dependencies/tests; result is `APPROVE` or `REQUEST_CHANGES`.
- Gemini verifies the final exact head, allowed paths, acceptance and evidence; result is `APPROVE` or `REJECT`.
- Unresolved reviewer/verifier disagreement is `NEEDS_HUMAN`; no agent arbitrates itself.
- CI repair: first actionable cause -> smallest justified repair -> targeted check -> new exact head -> new CI. Maximum 3 rounds.
- Tests are never weakened merely to obtain green.
- PR create/update is not merge authorization.
- Merge requires every gate plus the user's explicit request; prefer squash merge against the expected exact head SHA.
