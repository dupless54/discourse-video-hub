# Discourse Video Hub

A native Discourse video discovery and profile showcase plugin for public YouTube, TikTok, and Instagram links.

## Status

Phase 0 foundation is in progress. The repository currently provides:

- an isolated `VideoHub` Rails engine
- a guarded empty discovery feed API
- a native `/videos` Glimmer page
- light/dark responsive styling through Discourse color variables
- English and Turkish locales
- the official reusable Discourse plugin CI workflow
- project-specific architecture, security, and AI context rules

Publishing, provider metadata fetching, Topic/Post mapping, reactions, nested replies, profile layouts, and ranking are intentionally delivered in later reviewed phases.

## Architecture

Video metadata and presentation belong to the plugin. Comments, nested replies, reactions, notifications, flags, and moderation belong to standard Discourse Topic/Post infrastructure.

See [Project Brief](docs/PROJECT_BRIEF.md) and [Architecture](docs/ARCHITECTURE.md).

## Installation

Add the plugin repository to your Discourse container's `app.yml`, rebuild the container, then enable `video_hub_enabled` in site settings.

## Development

Follow root [AGENTS.md](AGENTS.md). Plugin tests have not yet been executed in a Discourse development checkout; consult `docs/ai/CURRENT_STATE.md` for current evidence.

## License

MIT
