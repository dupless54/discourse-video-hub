<p align="center">
  <a href="https://buymeacoffee.com/erespawn">
    <img src="https://cdn.buymeacoffee.com/buttons/v2/default-yellow.png" alt="Buy Me a Coffee" width="217" height="60">
  </a>
</p>

# Discourse Video Hub

A native Discourse video discovery and profile-showcase project for public YouTube, TikTok, and Instagram links.

Video Hub is designed around external public video URLs. It does **not** require Discourse to become a video-file hosting, download, re-hosting, or transcoding platform.

## Main Branch Status

The current `main` branch is the **Phase 0 foundation** and plugin version `0.1.0`.

Shipped on `main`:

- isolated `VideoHub` Rails engine mounted at `/videos`;
- guarded cursor-ready discovery-feed contract;
- native `/videos` Glimmer page and empty-state experience;
- responsive light/dark styling using Discourse theme variables;
- English and Turkish locales;
- request/component test sources;
- official reusable Discourse Plugin CI workflow;
- project-specific architecture, security, and development governance.

Publishing, provider fetching, canonical video persistence, Topic/Post discussion integration, profile layouts, ranking, and SEO work should not be treated as shipped on `main` merely because feature branches exist.

## Active Development Stack — Not Yet on `main`

Video Hub currently has a stacked draft development series. The upper part of that stack includes:

- **PR #26** — authorized profile layout management read contract;
- **PR #27** — profile video layout editor;
- **PR #28** — profile video membership mutations;
- **PR #29** — profile membership editor controls;
- **PR #30** — mobile active-player discovery feed;
- **PR #31** — canonical watch-page SEO;
- **PR #32** — backing-topic canonical integration;
- **PR #33** — sitemap alignment with Video Hub canonical URLs;
- **PR #34** — terminal watch SEO semantics for previously published unavailable videos;
- **PR #35** — crawl/index policy for aggregate Video Hub SPA surfaces.

These PRs are intentionally stacked and remain separate from `main` until their dependency order and repository delivery gates are satisfied. README readers should treat them as **in progress**, not released functionality.

## Product Architecture

The intended long-term model keeps Discourse core responsibilities intact:

- `VideoHub::Video` owns provider metadata, canonical public video identity, and Video Hub presentation state.
- Every published Video Hub item maps to a standard Discourse Topic and root Post.
- Topics/Posts remain authoritative for comments, nested replies, reactions, notifications, flags, revisions, and moderation.
- Video Hub does not create a second comment/reaction truth.
- Only allowlisted public provider URLs are accepted; users never submit iframe/embed HTML.
- Canonical uniqueness is based on provider + external video identity.

## Security Boundaries

Provider URL resolution and metadata fetching are SSRF-sensitive operations. Future provider integrations must preserve:

- strict host/scheme allowlists;
- DNS/IP public-address validation;
- bounded redirects with re-validation;
- short timeouts and response-size limits;
- sanitized provider/user metadata;
- server-side Guardian authorization for profile/video visibility.

Privacy-sensitive analytics should use minimal personal data, short retention, and aggregate metrics rather than indefinitely storing raw scrolling events.

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

Then enable `video_hub_enabled` in site settings.

## Development

Read [`AGENTS.md`](AGENTS.md) before implementation work. The current source/tests override older planning documents, and stacked PR features must not be described as released until they actually reach `main`.

Additional design context is available in [`docs/PROJECT_BRIEF.md`](docs/PROJECT_BRIEF.md) and [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md).

## Support

If you want to support the development of Video Hub, use the Buy Me a Coffee banner at the top of this README.
