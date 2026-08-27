# Discourse Video Hub — Project Brief

## Goal
Discourse içinde native görünen, responsive ve SEO-aware bir video merkezi oluşturmak. Üyeler public YouTube, TikTok ve Instagram bağlantıları paylaşır; videolar profillerde düzenlenir ve mobilde Shorts/Reels benzeri keşfet akışında tüketilir.

## V1 scope
- strict provider URL input and preview
- YouTube/Shorts, TikTok and public Instagram/Reels adapters
- publish flow backed by standard Topic + root Post
- canonical video watch page with nested comments and reactions
- `/videos` discovery feed for mobile and desktop
- user profile `Videolar` tab with editable Shorts and landscape sections
- drag/drop ordering and pin/hide placement controls
- core Guardian, trust-level, rate-limit, Reviewable and flag behavior
- Turkish/English locales and Discourse theme variables
- lazy players, background metadata refresh and bounded metrics
- canonical/OG/VideoObject/crawler/sitemap-compatible SEO seam
- admin settings for providers, permissions, category, limits and ranking weights

## Explicitly out of V1
- local video upload, download, proxy, transcoding or CDN hosting
- arbitrary iframe/embed HTML
- private/provider-authenticated media import
- custom reaction/comment/notification/moderation systems
- opaque ML ranking or biometric/device fingerprinting
- automatic Orb rewards or monetization

## Core user journeys
1. Member pastes a supported public URL, sees normalized preview, adds caption and publishes.
2. Server validates authorization/URL, creates or reuses canonical video, creates Topic/root Post when new, and redirects to the watch page.
3. Viewer reacts to the root Post and comments through core Nested Replies.
4. Member arranges Shorts and landscape videos in the profile `Videolar` tab.
5. Viewer vertically swipes the mobile feed; only the active item owns a player.
6. Staff reviews flags, edits/removes content and uses normal Discourse audit/moderation surfaces.

## V1 acceptance
- unsupported, private-looking or unsafe URLs fail server-side without network escape
- duplicate provider IDs do not create duplicate canonical discovery/topic truth
- hidden/inaccessible profile/topic/video data is not enumerable through HTML or JSON
- root Post reactions and reply reactions remain consistent on topic and video surfaces
- nested replies, notifications, edits, flags and deletions use core behavior
- profile order is deterministic and authorization-protected
- mobile feed supports touch, keyboard fallback, safe areas and reduced motion
- light/dark/custom schemes work without fixed palette overrides
- first load does not create every provider iframe; only one feed player is active
- watch pages expose one canonical URL and safe metadata
- targeted backend/frontend/security tests cover each boundary

## Planned extensions
Saved videos, playlists/series, creator follow feed, hashtags/categories, creator analytics, drafts/scheduling, captions/transcripts, source-health checks, sensitive-content gates, live links, weekly digests and abuse-resistant optional Orb rewards.
