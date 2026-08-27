# App Layer Rules

Applies to `app/models`, `app/controllers`, `app/serializers` and `app/services`.

- Read `docs/ARCHITECTURE.md` only for the touched ownership/public seam.
- Every show/list/mutate endpoint applies Guardian and standard Topic/Post visibility server-side.
- Inaccessible or hidden content returns standard `Discourse::NotFound`; do not expose existence through counts/errors.
- Strong params/contract validation precedes mutation. Client-provided owner, score, reaction count, view count, topic/post ID or provider metadata is untrusted.
- Publish/delete/layout operations use service objects and transactions where multiple truths change.
- Video/Topic/root Post mapping is one-to-one and idempotent; do not leave orphan records on partial failure.
- Reactions/comments call or expose core Post behavior; never mirror them into writable plugin counters.
- Serializers expose the minimum stable fields and permission flags needed by the frontend.
- List queries are paginated, indexed and visibility-filtered before serialization.
- User/provider text is stored/rendered safely; raw provider HTML is not a domain field.
- Add model/service/request specs for happy path, unauthorized path, invisible target and retry/duplicate path.
