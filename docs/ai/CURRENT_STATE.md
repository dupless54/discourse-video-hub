# Current State

## Project
- repository: `https://github.com/dupless54/discourse-video-hub`
- visibility: public
- phase: V1 feature-complete; repository-side `1.0.0-rc.1` release preparation is active
- current main SHA: `FRESH_READ_REQUIRED` (do not hard-code a self-changing state-file commit)
- verified integrated main baseline: `5f25d20e8f037a904a90d6627942d52df62fd472` (PR #70 squash merge)
- last verified release-documentation exact head: `215d0f7956945dd3a2a5cf08b06fcef02597c9bf`
- last verified release-documentation CI: Official Discourse Plugin run #387 / `33387015674` — `SUCCESS`
- last verified: 2026-08-31 UTC

## Active work
- branch: `release/v1.0.0-rc.1`
- goal: prepare the first public release candidate without claiming stable `1.0.0`
- scoped paths: `plugin.rb`, `CHANGELOG.md`, `docs/RELEASE_CHECKLIST.md`, `docs/ai/CURRENT_STATE.md`
- exact PR/head and CI must be fresh-read before delivery or merge claims

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
- release-candidate plugin metadata is being prepared as `1.0.0-rc.1`
- `CHANGELOG.md` now defines the integrated release-candidate scope
- `docs/RELEASE_CHECKLIST.md` defines repository gates plus the required real Discourse-instance smoke matrix
- no stable `v1.0.0` tag or GitHub Release has been published
- a real disposable/staging Discourse smoke pass remains required before stable promotion
- fresh official CI on every exact release/stable candidate head is mandatory; `NO_CI`, pending, cancelled, stale-head, neutral, skipped required checks, or failed checks are not GREEN

## Known blockers
- no unresolved V1 feature implementation blocker is known
- stable `1.0.0` is intentionally blocked until the release candidate is merged, post-merge CI is GREEN, and the deployed smoke checklist passes
- deploy, destructive database operations, force-push/reset/clean remain outside automatic release-prep authority

## Next action
- open the scoped `1.0.0-rc.1` release-prep PR and require latest exact-head Official Discourse Plugin CI GREEN
- if GREEN and scope is exact, squash merge; then verify post-merge `main` CI and perform the real-instance smoke checklist before stable promotion

Rules: fresh-read remote SHA/CI before claims; `NO_CI != GREEN`; `NOT_RUN != PASS`; merged source/tests override stale planning text; no stable-release claim without intentional version/tag and smoke verification.
