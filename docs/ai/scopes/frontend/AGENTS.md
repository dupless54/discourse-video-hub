# Video Hub Frontend Rules

- Follow current Discourse/Glimmer conventions and use `.gjs`; do not patch legacy widgets or core templates.
- Route maps are auto-discovered. Profile routes live under `/u/:username/...`.
- `user-main-nav` connector uses `@outletArgs.model`, renders its own `<li>` and honors `profile_hidden`.
- Forms use FormKit; requests use Discourse `ajax()` and server-supplied permission flags.
- Client is never authorization, ranking, ownership or visibility authority.
- Render untrusted caption/title/provider text escaped; no `htmlSafe`, `trustHTML` or triple-stash.
- Use Discourse color/spacing/icon/button/modal primitives. Preserve light, dark and custom schemes.
- Mobile feed: vertical snap, one active player, adjacent metadata/thumbnail only, pause/destroy on exit, stable cursor and cancelled stale requests.
- Provide keyboard/touch controls, visible focus, accessible labels, reduced-motion behavior and mobile safe-area padding.
- Shorts default to 9:16; landscape defaults to 16:9. Provider minimum player dimensions remain valid.
- Profile layout editor supports deterministic drag/drop plus keyboard movement and optimistic UI with server rollback on failure.
- Core reaction/comment state is not copied into client-owned truth; refresh from standard Post responses/events.
- Do not put AI metadata into runtime source directories. This file remains under `docs/ai/scopes/frontend/`.
