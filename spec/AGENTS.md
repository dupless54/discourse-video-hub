# Test Rules

Applies to backend specs and frontend acceptance/QUnit tests.

- Tests assert behavior/contracts, not private implementation details.
- Required backend boundaries: Guardian/IDOR, hidden profile/topic, duplicate publish/idempotency, Topic/Post mapping, nested mode inheritance, reaction target, deletion consistency, profile reorder concurrency and discovery visibility.
- Required provider boundaries: supported URL variants, unsafe scheme/host/IP, redirect revalidation, timeout, oversized/invalid payload, sanitization and token redaction.
- Required frontend journeys: publish preview/error, profile tab hidden/visible states, drag/drop plus keyboard alternative, light/dark, mobile feed single-player lifecycle, reduced motion, comment/reaction round trip and pagination cancellation.
- Freeze/seed ranking time and inputs; do not make probabilistic assertions.
- Never weaken security or integrity expectations just to satisfy CI.
- Run the narrowest affected tests first and report unavailable toolchain as `NOT_RUN`.
