# Validation Commands

Verified in this workspace:

```bash
node --check assets/javascripts/discourse/video-hub-route-map.js
node --check assets/javascripts/discourse/routes/videos.js
```

YAML, TOML, whitespace and SCSS delimiter checks were run through bounded local validation scripts. They are not substitutes for the Discourse plugin toolchain.

Commands to run once a Discourse development checkout is available:

```bash
LOAD_PLUGINS=1 bin/rspec plugins/discourse-video-hub/spec/requests/video_hub/videos_controller_spec.rb
bundle exec rake "plugin:spec[discourse-video-hub]"
CI=1 bundle exec rake "plugin:qunit[discourse-video-hub]"
```

Use the narrowest relevant check first. Until executed successfully, report these as `NOT_RUN`. `NO_CI != GREEN`.
