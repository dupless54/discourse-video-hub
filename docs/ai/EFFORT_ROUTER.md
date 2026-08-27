# Adaptive Model / Effort Router

Use the lowest-cost capability sufficient for the current risk.

## T0 — Mechanical
Examples: exact lookup, rename/move, locale/string edits, formatting, metadata,
generated annotations, obvious syntax repair, bounded CI-log classification.
Default: cheapest capable model, low effort, short turn/tool budget, no architecture exploration.

## T1 — Routine implementation
Examples: ordinary controller/service/frontend/spec work and bounded bug fixes.
Default: balanced coding model, medium effort.

## T2 — High-risk reasoning
Triggers: authorization/IDOR, schema/migrations, persistence constraints,
concurrency/idempotency, payments/refunds/balances, SSRF/network boundaries,
privacy, public API/contracts, cross-plugin integration, destructive operations.
Default: strongest practical reasoning model, high effort.

## T3 — Exceptional
Use only when targeted T2 investigation is insufficient.
Default: strongest available model, xhigh/max only when supported and justified.

## Escalation / de-escalation
- Start at the lowest sufficient tier.
- Escalate for risk or ambiguity, not merely task size.
- Escalate only the risky phase where possible.
- De-escalate after the risky phase.
- Never use T2/T3 for bulk mechanical edits.

## Hard safety rule
Cost optimization must never weaken authorization, tests, persistence integrity,
public contracts, CI evidence, security review, or destructive-operation safeguards.
`NO_CI != GREEN`. A new commit invalidates old exact-head CI evidence.
