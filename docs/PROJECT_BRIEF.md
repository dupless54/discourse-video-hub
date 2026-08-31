# Discourse Video Hub — Project Brief

## Goal
Discourse içinde native görünen, responsive ve SEO-aware bir video merkezi oluşturmak. Üyeler public YouTube, TikTok ve Instagram bağlantıları paylaşır; canonical videolar standart Discourse Topic/root Post tartışma yapısını korur, profillerde düzenlenir ve mobilde Shorts/Reels benzeri keşfet akışında tüketilir.

## Current delivery status
V1 implementation is feature-complete on `main`. Several capabilities that were originally listed as later extensions are also already integrated: Saved Videos, Trending, creator Following feed, and playlists/series collections.

The repository is therefore in **release-hardening** rather than feature-foundation mode. This does not mean a stable release has already been published: `plugin.rb` still reports `0.1.0`, and no GitHub Release/tag has been intentionally cut yet.

## V1 scope — implemented on main
- strict provider URL input, normalization, safety validation, and preview/publish metadata flow
- YouTube/Shorts, TikTok, and public Instagram/Reels provider handling
- publish flow backed by standard Topic + root Post
- canonical video watch page with core-backed likes, comments, nested replies, and saved state
- `/videos` discovery feed for mobile and desktop
- user profile `Videos` tab with editable Shorts and landscape sections
- authorized layout ordering plus pin/hide/visibility and canonical-video membership controls
- core Guardian, trust-level, rate-limit, Topic/Post moderation, Reviewable/flag-compatible behavior
- Turkish/English locales and Discourse theme variables
- lazy/controlled players, background metadata refresh, bounded cache, stale-metadata sweep, and bounded aggregate metrics
- deterministic/versioned discovery ranking with signed continuation cursors
- canonical/OG/Twitter/VideoObject/crawler/sitemap-compatible SEO seam
- admin settings for providers, permissions, category, limits, and ranking weights

## Shipped extensions beyond the original V1 list
- Saved Videos backed by Discourse core bookmarks
- Trending backend feed and responsive Trending page
- Following feed/page backed only by the official `discourse-follow` relationship when available
- public playlists and creator series
- owner collection CRUD, public collection read/page, safe video metadata payloads, atomic collection/item reorder, owner candidate catalog, and add-video UX

## Explicitly out of scope
- local video upload, download, proxy, transcoding, re-hosting, or CDN hosting
- arbitrary iframe/embed HTML supplied by users
- private/provider-authenticated media import
- custom reaction/comment/notification/moderation systems that duplicate Discourse core truth
- plugin-owned duplicate bookmark or follow graphs
- opaque ML ranking or biometric/device fingerprinting
- automatic Orb rewards or monetization

## Core user journeys
1. Member pastes a supported public URL, sees normalized preview, adds caption, and publishes.
2. Server validates authorization/URL/provider metadata, creates or reuses the canonical video, creates Topic/root Post when needed, and redirects to the canonical watch page.
3. Viewer reacts and comments through Discourse core discussion APIs, including nested replies.
4. Member arranges Shorts and landscape videos in the profile `Videos` tab and can add/remove eligible canonical videos.
5. Viewer vertically swipes the mobile feed; only the active item owns a provider iframe.
6. Authenticated users can save canonical videos using core bookmarks.
7. Users can browse Trending; when the official Follow plugin is available they can browse videos from followed creators.
8. Owners can create playlists/series, add eligible canonical videos, reorder collections/items, control public visibility, and expose public collection pages.
9. Staff continues to moderate the backing Topic/Post/content through normal Discourse authorization and moderation surfaces.

## V1 acceptance
Implemented code and automated coverage target the following boundaries:

- unsupported, private-looking, malformed, or unsafe URLs fail server-side without network escape
- duplicate provider IDs do not create duplicate canonical discovery/topic truth
- hidden/inaccessible profile/topic/video/collection data is not enumerable through public HTML or JSON contracts
- root Post reactions and nested discussion remain Discourse core truth
- notifications, edits, flags, deletions, and moderation use core behavior rather than plugin-side duplicates
- profile and collection ordering are deterministic and authorization-protected
- mobile feed supports touch, keyboard fallback, safe areas, and reduced motion
- light/dark/custom schemes work from Discourse variables without fixed palette overrides
- first load does not create every provider iframe; active mobile playback ownership remains bounded
- watch pages expose one canonical URL and safe metadata; backing Topic/sitemap semantics align with that canonical
- ranking/metrics use bounded aggregate data rather than persistent raw viewer-history or fingerprint storage
- targeted backend/frontend/security tests cover each boundary through the official Discourse Plugin CI

Before the first stable tag, these automated acceptance boundaries should be complemented by a real Discourse-instance smoke test of install/rebuild, migrations, publish/watch/discussion, discovery, profile, saved/trending/following, and collections.

## Planned extensions after the first stable release
- hashtags/topic-tag discovery surfaces where they add value without duplicating core taxonomy
- creator analytics built from privacy-bounded aggregates
- drafts and scheduling
- captions/transcripts and accessibility metadata
- source-health/availability diagnostics
- sensitive-content gates
- live-link experiences where provider contracts safely allow them
- weekly digests
- abuse-resistant optional Orb reward integrations

## Release principle
A capability is shipped only when it is present on `main`. A stable release is published only after an intentional semantic-version bump/tag, fresh exact-candidate official CI, release notes, and real-instance smoke verification.
