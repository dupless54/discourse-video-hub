# Discourse Video Hub Release Checklist

Use this checklist for the `1.0.0-rc.1` release candidate and promotion to the first stable `1.0.0` release.

## 1. Repository release-candidate gates

- [ ] `plugin.rb` reports the intended release-candidate version.
- [ ] `CHANGELOG.md` describes the exact integrated release scope.
- [ ] Latest exact release PR head has Official `Discourse Plugin` CI GREEN.
- [ ] Exact changed paths remain limited to the release-prep scope.
- [ ] No unresolved security, schema, product, architecture, or compatibility blocker exists.
- [ ] Release PR is squash merged with the expected exact head SHA.
- [ ] Post-merge `main` Official `Discourse Plugin` CI is GREEN.

## 2. Clean Discourse installation / upgrade smoke

Perform these checks on a real disposable or staging Discourse instance. Do not use production as the first smoke environment.

- [ ] Install or update the plugin from the release-candidate `main`/tag and rebuild Discourse successfully.
- [ ] Database migrations complete without error.
- [ ] Discourse boots normally with the plugin disabled.
- [ ] Enable `video_hub_enabled`; Discourse boots and `/videos` loads normally.
- [ ] Existing non-Video-Hub topics, profiles, bookmarks, reactions, and navigation still work.
- [ ] Light and dark color schemes render without obvious overflow or fixed-palette regressions.
- [ ] Desktop, tablet, and mobile layouts have no horizontal page overflow.

## 3. Provider and publishing smoke

Test with public URLs only.

- [ ] YouTube landscape URL resolves, previews, and publishes.
- [ ] YouTube Shorts URL resolves, previews, and publishes.
- [ ] TikTok public URL resolves, previews, and publishes when the provider is enabled.
- [ ] Instagram/Reels public URL resolves, previews, and publishes when the provider is enabled.
- [ ] Unsupported hosts and malformed URLs fail without provider metadata leakage.
- [ ] Publishing the same provider video again reuses canonical video identity instead of creating duplicate Video Hub truth.
- [ ] A published Video Hub item has the expected backing Topic and root Post.

## 4. Canonical watch and discussion smoke

- [ ] Canonical `/videos/:id/:slug` watch page loads the expected video.
- [ ] A wrong slug redirects to the canonical slug.
- [ ] Logged-out users can view permitted public content without mutation controls requiring authentication.
- [ ] Logged-in users can Like/unlike through the backing root Post.
- [ ] Root comments and nested replies are created/read through Discourse Post APIs.
- [ ] Core moderation/flagging behavior remains available through the backing Topic/Post.
- [ ] Save/unsave works and is reflected on the watch page.

## 5. Discovery, Saved, Trending, and Following smoke

- [ ] Desktop `/videos` discovery renders canonical cards and paginates.
- [ ] Mobile discovery keeps only one active provider iframe/player ownership at a time.
- [ ] Mobile touch scrolling and keyboard fallback navigation work.
- [ ] Authenticated impression/qualified-view requests do not interrupt playback when a metric request fails.
- [ ] `/videos/saved` shows only the current user's visible bookmarked Video Hub videos.
- [ ] `/videos/trending` loads ranked visible videos and paginates without duplicates.
- [ ] `/videos/following` requires authentication.
- [ ] When official `discourse-follow` is enabled, Following contains only visible videos from followed users.
- [ ] When official Follow integration is unavailable/disabled, the Video Hub boundary fails closed rather than inventing a second follow system.

## 6. Profile Videos smoke

- [ ] `/u/:username/videos` respects normal profile visibility.
- [ ] Shorts and landscape sections render in deterministic order.
- [ ] Owner/staff layout editor authorization works; another normal user cannot edit the profile.
- [ ] Existing canonical videos can be added/removed from the profile without duplicating video/topic truth.
- [ ] Section/item reorder persists correctly.
- [ ] Pin/hide/visibility changes persist and do not expose hidden content to unauthorized viewers.
- [ ] Mobile profile layout remains usable without overflow.

## 7. Collections smoke

- [ ] Owner can create, edit, hide/show, and delete a playlist.
- [ ] Owner can create and manage a creator series.
- [ ] Playlist catalog can offer visible canonical videos from other creators where permitted.
- [ ] Series catalog offers only eligible canonical videos owned by the series owner.
- [ ] Existing collection memberships are excluded from the add-video catalog.
- [ ] Add-video, remove-video, collection reorder, and item reorder persist correctly.
- [ ] Public collection pages expose only visible collection/video data.
- [ ] Foreign/private collection IDs fail closed.
- [ ] Desktop and mobile collection management layouts remain usable without overflow.

## 8. SEO and crawler smoke

- [ ] Canonical public watch page emits exactly one canonical URL.
- [ ] Backing Topic canonical points to the Video Hub watch URL when the video is public/indexable.
- [ ] Sitemap uses canonical Video Hub URLs for eligible public Video Hub topics.
- [ ] Aggregate Video Hub SPA surfaces send `noindex,follow` rather than competing with watch pages.
- [ ] Previously published terminal unavailable public content uses the intended `410` + `noindex` behavior.
- [ ] Private/hidden/provider-disabled content remains non-enumerable through watch, profile, collection, feed, and sitemap surfaces.

## 9. Promotion to stable `1.0.0`

Only after all applicable smoke checks above pass:

- [ ] Record the tested Discourse branch/version and enabled companion plugins/settings.
- [ ] Record smoke-test date and tester.
- [ ] Open a narrowly scoped stable-version PR changing `1.0.0-rc.1` to `1.0.0` and finalizing changelog status.
- [ ] Require fresh exact-head Official `Discourse Plugin` CI GREEN on that stable-version PR.
- [ ] Squash merge the exact GREEN head.
- [ ] Confirm post-merge `main` CI GREEN.
- [ ] Create signed/annotated release tag `v1.0.0` from the verified stable merge commit.
- [ ] Publish GitHub Release notes from the finalized changelog.

A failed required smoke item blocks stable promotion until it is fixed and re-verified.
