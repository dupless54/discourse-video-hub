---
name: project-schema-review
description: Review Video Hub migrations/indexes/constraints for integrity.
---
# Schema Review
Check null/default/status values; database uniqueness for `(provider, external_id)` and Topic/Post mapping; profile scoped ordering; reference/deletion strategy; indexes against actual feed/profile/lookup queries; bounded metric retention; migration safety; concurrency/idempotency; and existing-data compatibility.
