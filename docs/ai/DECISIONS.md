# Durable Decisions

- Plugin name/namespace: `discourse-video-hub` / `VideoHub`.
- V1 accepts public external video URLs only; it does not upload, download, proxy or transcode video files.
- `VideoHub::Video` owns normalized provider metadata and presentation state.
- Standard Topic/root Post own discussion, reactions/likes, notifications, flags, revisions and moderation.
- One canonical video maps to one backing Topic and root Post. `provider + external_id` is unique.
- Duplicate submissions reuse the canonical video; they may create profile/save placement, not duplicate discovery/topic truth.
- Core Nested Replies is enabled for the dedicated video category; no custom comment tree.
- Core Like and optional official `discourse-reactions` operate on Posts; no custom reaction table.
- Guardian and standard Discourse visibility are authoritative on every HTML/JSON path.
- Provider adapters return normalized data only. Raw provider HTML is never the storage/render contract.
- `/videos/:id/:slug` is canonical and indexable. Backing `/t/` surface redirects or advertises the video canonical to prevent duplicate SEO.
- Profile layout changes placement/order only; they do not transfer video/topic ownership.
- Discovery score is server-owned, versioned and derived from bounded/aggregated signals. The owner's own activity does not boost ranking.
- External embeds are lazy and at most one feed player is active. Metadata/thumbnail precedes iframe creation.
- Light/dark styling uses Discourse color variables; no fixed product palette.
- Turkish and English are first-class locales.

Temporary implementation/PR/CI status belongs only in `CURRENT_STATE.md`.
