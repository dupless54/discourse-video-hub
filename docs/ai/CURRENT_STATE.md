# Current State

## Project
- repository: `https://github.com/dupless54/discourse-video-hub`
- visibility: public
- phase: V1 feature-complete; `1.0.0-rc.1` is merged and repository-CI verified; deployed smoke verification is next
- current main SHA: `FRESH_READ_REQUIRED` (do not hard-code a self-changing state-file commit)
- verified release-candidate main baseline: `4f68ad49f912745303683e37c53c039f85771175` (PR #71 squash merge)
- release-candidate exact PR head: `e03c9d50971ca3cca66ca265cd63ce90fd962f38`
- exact-head release CI: Official Discourse Plugin run #389 / `33389224236` — `SUCCESS`
- post-merge main CI: Official Discourse Plugin run #390 / `33389546207` — `SUCCESS`
- last verified: 2026-08-31 UTC

## Active work
- repository-side `1.0.0-rc.1` preparation is complete
- no runtime release-prep branch is required for the next step
- next release gate is the real disposable/staging Discourse smoke matrix in `docs/RELEASE_CHECKLIST.md`
- exact main/tag/release state must still be fresh-read before publication claims

## Implemented on main
- strict public YouTube/Shorts, TikTok, and Instagram/Reels provider URL resolution and metadata fetching
- canonical Video persistence with standard Discourse Topic/root Post publish and discussion truth
- canonical watch page, core-backed likes/comments/nested replies, and saved-video state
- responsive desktop discovery and mobile single-active-player vertical feed
- bounded aggregate metrics, versioned ranking, signed ranking cursors, and Trending feed/page
- Saved Videos backed by Discourse core bookmarks
- Following feed/page backed only by official `discourse-follow` relationships when available
- profile Videos tab, authorized layout editor, canonical-video membership add/remove, reorder, pin/hide, and visibility controls
- public playlists/series, owner collection CRUD, safe public read, atomic collection/item reorder, owner catalog API, and add-video UX
- bounded metadata cache, background refresh, and stale metadata sweeper
- canonical/OG/Twitter/VideoObject SEO, backing-topic canonical, sitemap alignment, terminal unavailable semantics, and aggregate `noindex,follow` crawl policy
- English/Turkish locales, Discourse theme variables, responsive/mobile safe-area, focus-visible, and reduced-motion handling
- official reusable Discourse Plugin CI coverage for lint/format/types/backend/frontend/annotations and migration/runtime checks

## Release readiness
- `plugin.rb` reports `1.0.0-rc.1`
- `CHANGELOG.md` contains the integrated RC scope
- `docs/RELEASE_CHECKLIST.md` contains repository gates plus the required real-instance smoke matrix
- release candidate has exact-head and post-merge Official Discourse Plugin CI GREEN
- no stable `v1.0.0` tag or stable GitHub Release has been published
- a real disposable/staging Discourse smoke pass remains mandatory before stable promotion
- after smoke, stable promotion must use a narrowly scoped `1.0.0` version PR with fresh exact-head and post-merge CI GREEN

## Known blockers
- no unresolved V1 feature implementation or repository-CI blocker is known
- stable `1.0.0` is blocked only on deployed smoke verification and the intentional stable-version/tag/release sequence
- deploy, destructive database operations, force-push/reset/clean remain outside automatic repository authority

## Next action
- install/update exact `1.0.0-rc.1` on a disposable or staging Discourse instance and complete `docs/RELEASE_CHECKLIST.md`
- if every required smoke item passes, open the narrow `1.0.0` promotion PR and repeat exact-head/post-merge CI before stable tag/release publication

Rules: fresh-read remote SHA/CI before claims; `NO_CI != GREEN`; `NOT_RUN != PASS`; merged source/tests override stale planning text; no stable-release claim without deployed smoke verification and intentional stable version/tag.
