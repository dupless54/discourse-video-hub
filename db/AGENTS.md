# Schema and Migration Rules

Applies to `db/migrate`, schema constraints and persistence indexes.

- Review with `.agents/skills/project-schema-review/SKILL.md`.
- Enforce canonical uniqueness for `(provider, external_id)` at the database layer.
- Enforce one-to-one Topic/Post mapping where nullable publish stages permit it; application validation alone is insufficient.
- Foreign-key/reference strategy must match Discourse plugin conventions and deletion lifecycle.
- Status/provider/kind/default/null semantics are explicit and existing-row safe.
- Profile section/item positions have deterministic scoped uniqueness or a transaction-safe reorder strategy.
- Index real query shapes: visibility/status + publish/score cursor, author profile ordering, Topic/Post lookup and metric aggregation.
- Do not add unbounded raw event or provider response storage.
- Large backfills are batched/restartable; avoid long locks. Destructive cleanup requires explicit authorization and recovery plan.
- Migration specs or targeted migration validation cover fresh install and upgrade paths where applicable.
