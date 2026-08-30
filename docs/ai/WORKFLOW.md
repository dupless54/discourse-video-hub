# Delivery Workflow

`Task packet -> implementation -> targeted validation -> PR -> latest exact-head Discourse CI -> merge`

## Gates
- Lock goal, allowed paths, acceptance, validation and risk before implementation.
- Any capable model may build, inspect, or repair the task; AI approvals are not merge requirements.
- Cheap-first validation: syntax/static -> narrow specs -> plugin suite -> frontend QUnit/build -> broader/system only if justified.
- PR/CI evidence must match the latest exact head. A new commit invalidates all prior CI evidence.
- Official `Discourse Plugin` CI must be GREEN on the latest exact PR head; any additional required Discourse-owned CI/check context must also be GREEN.
- `NO_CI`, missing, skipped, pending, cancelled, neutral, stale-head, or failed checks are not GREEN.
- Exact changed paths must remain within the task scope.
- CI repair: first actionable cause -> smallest justified repair -> targeted check -> new exact head -> new CI. Maximum 3 rounds.
- Tests are never weakened merely to obtain green.
- When the latest exact head is GREEN and no unresolved security/schema/product/architecture blocker remains, the agent is authorized to merge without additional user confirmation. Prefer squash merge against the expected exact head SHA.
