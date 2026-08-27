# Example Task-Specific AGENTS.md

Bu dosya yeni bir subsystem eklendiğinde local `AGENTS.md` yazmak için örnektir. Root invariant'ları tekrarlama.

## Scope
- Applies to: `<exact paths>`
- Does not apply to: `<excluded paths>`

## Local ownership
- `<component>` owns `<state>`.
- `<consumer>` uses `<public seam>` only.

## Local invariants
- Authorization remains server-side.
- Invalid transitions fail server-side.
- Retry/concurrency integrity is persistence-backed where required.
- Tests cover the local contract and its nearest failure boundary.

## Read expansion trigger
- Load `<specific dependency/doc>` only when `<specific risk>` is touched.
