# Discourse Video Hub — Architecture

## Ownership

| Concern | Source of truth |
|---|---|
| Provider identity/metadata/canonical URL | `VideoHub::Video` |
| Author and publish lifecycle | `VideoHub::Video` + backing Topic/root Post |
| Comments/nesting/revisions/flags | Discourse Post/Topic |
| Like/reactions | root/reply Post actions and optional official Reactions plugin |
| Notifications/moderation/trust | Discourse core |
| Profile presentation | profile section/item records |
| Discovery aggregates/score | bounded metric aggregates + ranking service/version |

## Proposed data model

### `video_hub_videos`
`user_id`, `topic_id`, `post_id`, `provider`, `external_id`, `canonical_url`, `kind`, safe title/description/thumbnail/duration, `status`, `published_at`, bounded normalized metadata and ranking cache.

Required constraints: unique `(provider, external_id)`, unique non-null `topic_id`, unique non-null `post_id`, valid status/provider/kind, indexed author/status/published/score query paths.

### `video_hub_profile_sections`
Owner, section type (`shorts`/`landscape`), title, position and display settings. Position changes must be transactional and scoped to one owner.

### `video_hub_profile_items`
Section/video join with position, pin/visibility state and uniqueness preventing duplicate placement inside a section.

### Metrics
Prefer daily/hourly aggregates for impression, qualified view, completion bucket, reaction, comment, save, hide and report signals. Keep only the minimum short-lived per-user/session state needed for dedupe, history and personalization; define retention before implementation.

## Publish transaction
1. Guardian/trust/rate-limit checks.
2. Parse URL locally; reject unsupported scheme/host/path.
3. Normalize provider and external ID; check canonical uniqueness.
4. Fetch metadata only through the SSRF-safe provider boundary.
5. Sanitize and validate normalized metadata.
6. In an idempotent operation, create Topic/root Post and Video mapping; compensate or fail without orphan truth.
7. Enqueue non-critical refresh/index work after commit.
8. Return the canonical watch URL.

Duplicate policy: reuse the existing canonical video. A user may save/add it to a profile collection, but no second discovery entry/topic/comment tree is created.

## Provider contract
Each adapter exposes local URL matching/parsing plus normalized metadata retrieval. It never returns render-ready arbitrary HTML. Fetcher enforces HTTPS, exact host allowlist, public resolved IP, redirect revalidation, timeout, response byte/type limit and safe error mapping. Secrets remain server-side and filtered from logs.

## Discourse integration
- Dedicated public video category is configured by SiteSetting; new topics inherit core Nested Replies.
- Root Post raw content contains canonical link and caption so the normal topic remains a valid fallback/Onebox source.
- Watch page reads the backing Topic through Guardian and renders core-compatible post/reply data.
- Video reaction targets root Post; comment reaction targets its reply Post. No counter mirroring writes.
- Optional `discourse-reactions` is feature-detected; standard Like remains the fallback.
- Deletion/edit/flag operations call core-authorized services and keep mappings consistent.

## Frontend routes
- `/videos`: discovery
- `/videos/new`: FormKit publish flow
- `/videos/:id/:slug`: canonical watch/comments
- `/videos/following`, `/videos/trending`, `/videos/saved`: extension-ready filters
- `/u/:username/videos`: profile tab
- `/u/:username/videos/manage`: owner/staff layout editor

Use auto-discovered route maps, modern `.gjs` components and Discourse plugin outlets. `user-main-nav` connector renders its own `<li>`, uses `@outletArgs.model`, honors `profile_hidden`, and routes under `/u/:username/...`.

## Feed performance
Use vertical CSS scroll snap on mobile with explicit keyboard controls. Instantiate only the active iframe/player; pause/destroy it on exit. Preload bounded thumbnails/metadata for adjacent items, paginate by stable cursor, cancel stale requests, respect `prefers-reduced-motion`, safe areas and provider minimum player dimensions.

## Discovery
Start with explainable versioned ranking, not opaque ML. Candidate generation applies Guardian/visibility/status/dedupe first. Ranking may combine qualified completion, reactions, comments, saves, freshness, creator diversity and exploration; quick skips, hides, reports and repetition are negative. Owner activity cannot boost its own video. Rate limits and anomaly caps protect signals.

## SEO
`/videos/:id/:slug` is the only indexable canonical watch URL. It supplies server-visible title/description, canonical, Open Graph and safe `VideoObject` JSON-LD when required fields exist. Backing topic redirects or declares the video canonical. Feed/profile pagination remains crawlable without indexing infinite client state. Deleted/private/unavailable items return correct 404/410/noindex behavior without leaking existence.

## Public seam
Frontend consumes versioned serializers/controllers, not database shape. Cross-plugin integrations may subscribe to documented events or read a small service contract; direct table coupling is forbidden. Orb/reward integration is future work and must consume qualified, fraud-resistant events without owning video state.
