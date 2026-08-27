# Provider and Security Rules

Applies to provider adapters, URL parsing, network fetch, engine integration and public contracts under `lib/`.

- Supported providers are explicit allowlist entries; arbitrary oEmbed discovery is forbidden.
- Accept HTTPS canonical/share URLs only. Parse locally before network access.
- Validate host exactly; suffix/substring matches are invalid. Normalize known mobile/share hosts deliberately.
- Resolve DNS and reject loopback, private, link-local, multicast, reserved, metadata and other non-public targets for every request and redirect.
- Redirect count, connect/read timeout, response bytes, MIME type and JSON depth/shape are bounded.
- Never send Discourse cookies, auth headers or internal secrets to provider URLs. Provider tokens remain server-side and filtered from logs/errors.
- Store normalized fields, not provider-supplied scripts or arbitrary embed HTML. Render from owned templates/approved iframe URLs.
- Revalidate provider/external ID after redirect and prevent URL confusion/credential components.
- Cache successful metadata with bounded TTL; negative-cache safe failures. Background refresh must be idempotent and rate-limited.
- Adapter errors map to stable safe codes without leaking internal hosts, tokens or raw responses.
- Tests cover SSRF addresses, DNS/redirect rebinding boundaries, oversized/invalid responses, timeout and provider URL variants.
