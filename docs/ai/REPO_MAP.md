# Repository Map

Navigation hint only; source/tests are authority. Phase 0 paths below exist; later planned paths must be verified before use.

- `plugin.rb`: plugin registration, assets, settings, engine mount, optional integration hooks
- `lib/video_hub/engine.rb`: isolated Rails engine and routes
- `lib/video_hub/providers/`: URL parsing and normalized provider adapters
- `lib/video_hub/network/`: SSRF-safe fetch boundary
- `app/controllers/video_hub/videos_controller.rb`: Phase 0 empty discovery API
- `app/models/video_hub/`: planned video/profile persistence; not created
- `app/services/video_hub/`: planned publish/refresh/layout/ranking operations; not created
- `app/serializers/video_hub/`: planned stable serializers; not created
- `app/jobs/`: planned metadata and aggregation jobs; not created
- `db/migrate/`: planned schema; no migrations yet
- `config/settings.yml`: provider, permission, feed and privacy settings
- `config/locales/{client,server}.{en,tr_TR}.yml`: paired locales
- `assets/javascripts/discourse/`: Phase 0 route, route model, template and landing component
- `assets/stylesheets/common/video-hub.scss`: Discourse-variable-based responsive foundation
- `spec/requests/video_hub/`: Phase 0 feed contract test; domain/security specs planned
- `test/javascripts/integration/components/`: Phase 0 landing component test
- `docs/ai/scopes/frontend/`: frontend AI context; never runtime source
