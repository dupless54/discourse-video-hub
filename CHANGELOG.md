# Changelog

All notable release milestones for Discourse Video Hub are recorded here.

## [1.0.0-rc.1] - 2026-08-31

First public release candidate for the integrated Video Hub V1 baseline.

### Added

- Public YouTube/Shorts, TikTok, and Instagram/Reels URL resolution with bounded provider metadata fetching and canonical video identity.
- Topic/root-Post-backed publishing so Discourse remains the source of truth for comments, nested replies, reactions, notifications, flags, revisions, and moderation.
- Canonical `/videos/:id/:slug` watch pages with provider playback, core-backed discussion, saved state, and crawler-safe SEO metadata.
- Responsive desktop discovery plus a mobile vertical feed with a single active player, keyboard fallback, safe-area handling, and reduced-motion behavior.
- Bounded aggregate video metrics, versioned ranking signals/scores, frozen ranking context, signed ranking cursors, and a Trending feed/page.
- Saved Videos backed by Discourse core bookmarks.
- Following feed/page backed by the official `discourse-follow` relationship when that plugin is available and enabled.
- Profile Videos tab with authorized layout management, add/remove membership, reorder, pin/hide, and visibility controls.
- Public playlists and creator series with owner CRUD, safe public reads, atomic collection/item reorder, owner candidate catalog, and add-video UX.
- Bounded provider metadata cache, background refresh, and stale metadata sweeper.
- Canonical/OG/Twitter/VideoObject SEO, backing-topic canonical alignment, sitemap integration, terminal unavailable semantics, and `noindex,follow` policy for aggregate SPA surfaces.
- English and Turkish locales and responsive styling based on Discourse theme variables.
- Official reusable Discourse Plugin CI covering linting, formatting, types, backend/frontend tests, annotations, migrations, and runtime checks.

### Security and privacy

- Strict provider host/scheme allowlists, public-IP validation, redirect re-validation, request timeouts, response-size bounds, and sanitized metadata at provider-fetch boundaries.
- Server-side Guardian checks remain authoritative for video, topic, post, profile, collection, and feed visibility.
- Discovery metrics persist bounded daily aggregates instead of long-lived raw viewer event history or device fingerprints.
- Provider iframe/embed HTML is never accepted from users.

### Release status

- This is a **release candidate**, not the first stable release.
- A deployed Discourse-instance smoke pass is required before promoting this baseline to `1.0.0`.
- No local video upload, proxying, transcoding, downloading, or CDN hosting is included.
