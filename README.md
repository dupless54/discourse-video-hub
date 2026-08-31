<p align="center">
  <a href="https://buymeacoffee.com/erespawn">
    <img src="https://cdn.buymeacoffee.com/buttons/v2/default-yellow.png" alt="Buy Me a Coffee" width="217" height="60">
  </a>
</p>

# Discourse Video Hub

A native Discourse video discovery, publishing, profile-showcase, saved-video, follow-feed, trending, and collection experience for public YouTube, TikTok, and Instagram links.

Video Hub is designed around external public video URLs. It does **not** require Discourse to become a video-file hosting, download, re-hosting, proxy, transcoding, or CDN platform.

## Main Branch Status

The current `main` branch contains the completed V1 product scope plus several originally planned extensions. Plugin metadata is now **`1.0.0-rc.1`**. The release-candidate merge commit passed the post-merge Official Discourse Plugin CI on `main`, so the repository baseline is CI-verified as the first release candidate. A real staging/disposable Discourse smoke pass is still required before stable `1.0.0` promotion.

Shipped on `main`:

- strict supported-provider URL resolution for public YouTube/Shorts, TikTok, and Instagram/Reels links;
- SSRF-aware provider metadata fetching, bounded metadata caching, background refresh, and stale-metadata sweeping;
- canonical `VideoHub::Video` persistence backed by standard Discourse Topic + root Post discussion truth;
- publish flow with canonical-video reuse, server-side authorization, provider controls, category controls, and bounded rate limits;
- canonical watch pages with safe provider playback, core-backed likes, comments, nested replies, and saved-video controls;
- responsive desktop discovery plus a mobile vertical active-player feed that keeps only one active provider iframe;
- bounded aggregate view metrics, versioned ranking signals/score/context, signed ranking cursors, and a dedicated Trending feed/page;
- Saved Videos backed by Discourse core bookmarks rather than plugin-owned duplicate persistence;
- Following feed/page backed by the official `discourse-follow` relationship when that plugin is available and enabled;
- profile `Videos` surfaces with Shorts/landscape sections, owner/staff editing, membership add/remove, reorder, pin, hide, and visibility controls;
- public playlists/series plus owner collection management, canonical-video catalog add flow, removal, and atomic collection/item reordering;
- canonical watch SEO, safe Open Graph/Twitter metadata, `VideoObject` JSON-LD, backing-topic canonical alignment, sitemap alignment, terminal unavailable semantics, and `noindex,follow` aggregate SPA policy;
- responsive light/dark/custom-scheme styling built from Discourse theme variables, including mobile safe-area and reduced-motion handling;
- English and Turkish client/server locale coverage;
- official reusable Discourse Plugin CI with lint, formatting, type, backend, frontend, annotation, and migration/runtime checks.

## Release Status

`1.0.0-rc.1` is the first repository-verified release candidate. The scoped release-prep PR and its post-merge `main` workflow both passed Official Discourse Plugin CI. The integrated release notes are in [`CHANGELOG.md`](CHANGELOG.md), and the required real-instance validation matrix is in [`docs/RELEASE_CHECKLIST.md`](docs/RELEASE_CHECKLIST.md).

Before promoting to stable `1.0.0`:

- install/update this exact candidate on a disposable or staging Discourse instance;
- complete the provider, publish/watch/discussion, discovery, Saved/Trending/Following, profile, collection, SEO/privacy, light/dark, and responsive smoke matrix;
- verify optional integrations, especially `discourse-follow`, fail closed when unavailable;
- open a narrowly scoped stable-version PR from `1.0.0-rc.1` to `1.0.0` and require fresh exact-head plus post-merge Official Discourse Plugin CI GREEN;
- only then create the stable tag and GitHub Release.

No stable `v1.0.0` tag or stable GitHub Release is claimed by this repository state.

## Product Architecture

Video Hub keeps Discourse core responsibilities intact:

- `VideoHub::Video` owns provider metadata, canonical public video identity, and Video Hub presentation state.
- Every newly published Video Hub item maps to a standard Discourse Topic and root Post; reused canonical videos keep one canonical discussion truth.
- Topics/Posts remain authoritative for comments, nested replies, reactions, notifications, flags, revisions, and moderation.
- Discourse core `Bookmark` remains authoritative for saved videos.
- The official `discourse-follow` relationship is the only Following-feed social source when that integration is enabled.
- Profile layouts and video collections store presentation/membership state around canonical videos; they do not duplicate provider/video/discussion truth.
- Only allowlisted public provider URLs are accepted; users never submit iframe/embed HTML.
- Canonical uniqueness is based on provider + external video identity.

## Security Boundaries

Provider URL resolution and metadata fetching are SSRF-sensitive operations. The implementation preserves:

- strict provider host/scheme allowlists;
- DNS/IP public-address validation;
- bounded redirects with re-validation;
- short timeouts and response-size limits;
- sanitized provider/user metadata;
- server-side Guardian authorization for video, profile, collection, Topic, and Post visibility;
- fail-closed handling for unavailable/hidden/private backing content;
- bounded metric aggregation without persistent raw viewer-event, session, device, or fingerprint history.

## Optional Integration

The Following surface uses the official `discourse-follow` plugin. If that plugin, its setting, or the expected following association is unavailable, Video Hub does not create its own substitute follow graph and the backend fails closed for that feed.

## Installation

Add the plugin repository to your Discourse container configuration:

```yaml
hooks:
  after_code:
    - exec:
        cd: $home/plugins
        cmd:
          - git clone https://github.com/dupless54/discourse-video-hub.git
```

Rebuild Discourse:

```bash
cd /var/discourse
./launcher rebuild app
```

Then enable `video_hub_enabled` in site settings and configure the Video Hub provider/category/ranking settings required by your community.

## Development

Read [`AGENTS.md`](AGENTS.md) before implementation work. Current source, tests, and merged PR state override older planning text. Features must not be described as released until they are present on `main`, and a stable release must not be inferred until a release tag/version is intentionally published.

Additional design context is available in [`docs/PROJECT_BRIEF.md`](docs/PROJECT_BRIEF.md) and [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md).

## Support

If you want to support the development of Video Hub, use the Buy Me a Coffee banner at the top of this README.
