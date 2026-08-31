# Discourse Video Hub — Canonical Agent Instructions

## Context priority
Current source/tests > `docs/ai/CURRENT_STATE.md` > nearest applicable local `AGENTS.md` > `docs/ARCHITECTURE.md` > stable docs > plans/history.

## Fast path
Non-trivial work için `.agents/skills/task-packet/SKILL.md` kullan.
Varsayılan okuma: root `AGENTS.md` -> `CURRENT_STATE.md` -> nearest local `AGENTS.md` -> hedef source/tests -> yalnız gerektiğinde mimari/skill.
Tercih: `symbol/search -> targeted range -> dependency`.

## Product boundary
`discourse-video-hub`, kullanıcıların herkese açık YouTube, TikTok ve Instagram video bağlantılarını paylaşabildiği; profil vitrini, keşfet akışı, Discourse Reactions ve core Nested Replies entegrasyonu sağlayan bir Discourse eklentisidir.

V1 haricî bağlantı tabanlıdır. Video dosyası yükleme, indirme, yeniden barındırma veya transcoding kapsam dışıdır.

## Durable invariants
- Discourse core değiştirilmez; tüm davranış eklenti sınırında kalır.
- `VideoHub::Video` video metadata, sağlayıcı kimliği, canonical video URL ve profil/keşfet sunumunun kaynağıdır.
- Her video standart bir Discourse Topic ve kök Post ile eşlenir. Topic/Post; yorum, nested reply, reaction/like, bildirim, flag, revision ve moderasyon gerçeğinin sahibidir.
- Ayrı reaction veya comment gerçeği oluşturma. Video tepkisi kök Post'a, yorum tepkisi ilgili reply Post'a yazılır.
- Dedicated video kategorisinde core Nested Replies kullanılır; özel yorum ağacı veya paralel bildirim sistemi kurulmaz.
- Yetkilendirme her istekte server-side Guardian ile yapılır. Profil/video görünürlüğü Discourse gizlilik kurallarını genişletir, atlamaz.
- Kullanıcıdan iframe/HTML/embed kodu kabul edilmez. Yalnız allowlist provider URL'leri kabul edilir.
- URL çözümleme, redirect, DNS/IP ve metadata fetch işlemleri SSRF sınırıdır: strict host/scheme allowlist, public-IP doğrulama, timeout, boyut limiti, redirect yeniden doğrulaması ve sanitize zorunludur.
- `provider + external_id` canonical uniqueness sınırıdır. Aynı haricî video keşfette çoğaltılmaz; mevcut video profil koleksiyonuna eklenebilir.
- `/videos/:id/:slug` indexlenebilir canonical watch page'dir. Backing topic duplicate SEO yüzeyi oluşturmaz.
- Keşfet client state'e güvenmez. Puanlama server-authoritative, sürümlü, kötüye kullanım dirençli ve gerektiğinde yeniden üretilebilir olmalıdır.
- Ham kaydırma olaylarını süresiz saklama. Minimum kişisel veri, kısa retention ve aggregate metrikler kullan.
- Modern Glimmer `.gjs`, Discourse route/controller/serializer kalıpları, `ajax()`, FormKit ve mevcut tema değişkenleri kullanılır.
- Light/dark, mobile/desktop, keyboard, reduced-motion ve safe-area davranışı korunur.
- Kullanıcı/provider metni escaped render edilir; `htmlSafe`, `trustHTML` ve triple-stash kullanılmaz.
- Türkçe ve İngilizce locale birlikte güncellenir.

## Context router
- models/controllers/serializers/services -> `app/AGENTS.md`
- provider adapters/network/security -> `lib/AGENTS.md`
- migrations/schema/indexes -> `db/AGENTS.md`
- backend/frontend tests -> `spec/AGENTS.md`
- Glimmer/routes/profile/feed/theme -> `docs/ai/scopes/frontend/AGENTS.md`
- architecture/public contracts -> `docs/ARCHITECTURE.md`

## Adaptive context and effort
Broad read öncesi `docs/ai/EFFORT_ROUTER.md` ile T0-T3 seç.
Schema, authorization/IDOR, SSRF/network, privacy, provider/public API, persistence/concurrency, discovery abuse veya cross-plugin sınırları T2'dir.
Riskli faz bittikten sonra T0/T1'e dön. Correctness ve safety token tasarrufundan üstündür.

## CI-only delivery governance
- Goal, allowed paths, acceptance ve validation task packet içinde kilitlenir.
- Unrelated refactor veya dependency ekleme yapılmaz.
- Claude/Gemini/Codex reviewer veya verifier approval merge şartı değildir; bu onayları bekleme veya isteme.
- Merge eligibility yalnız latest exact PR head CI durumuyla belirlenir.
- Official `Discourse Plugin` CI latest exact head üzerinde GREEN olmalıdır; varsa ek required Discourse-owned CI/check context'leri de GREEN olmalıdır.
- Yeni commit eski CI kanıtını geçersiz kılar. `NO_CI`, missing, skipped, pending, cancelled, stale-head veya failed durumları GREEN değildir. `NOT_RUN != PASS`.
- Exact changed paths görev kapsamıyla eşleşmeye devam etmelidir.
- Latest exact head GREEN ve unresolved security/schema/product/architecture blocker yoksa agent ayrıca kullanıcı onayı beklemeden merge etmeye yetkilidir; mümkünse squash + `expected_head_sha` kullan.
- Testleri yalnız CI yeşili için zayıflatma. CI repair en fazla 3 bounded tur; sonra `NEEDS_HUMAN`.
- Force-push/reset/clean/deploy/destructive DB gibi yıkıcı işlemler ayrı açık yetki gerektirir.

## Runtime asset guardrail
AI context dosyalarını runtime-compiled klasörlere koyma. Özellikle `assets/javascripts/{AGENTS,CLAUDE,GEMINI}.md` kullanma. Frontend context `docs/ai/scopes/frontend/` altında kalır.

## Platform adapters
`CLAUDE.md`, `GEMINI.md`, `.claude/` ve `.codex/` canonical kuralları tekrar etmez; bu dosyaya ve `EFFORT_ROUTER.md`'ye yönlendirir.

## Live Discourse developer source gate
Canonical live upstream index: https://meta.discourse.org/t/developer-guides-index/308036?tl=en

For any Discourse-version-sensitive implementation, refactor, review, or compatibility decision:
- start at the live Developer Guides Index and open only the task-relevant official topic(s);
- for plugin work prioritize **Code & Internals + Plugins**; for theme work prioritize **Code & Internals + Themes & Components / Theme Developer Tutorial**; use environment/general guides only when relevant;
- verify version-sensitive APIs and deprecations against current `discourse/discourse` core or the current official plugin/theme skeleton before coding when needed;
- current official docs/core beat remembered examples, old snippets, and copied local guidance unless the repo deliberately targets an older validated release via `.discourse-compatibility` / d-compat;
- do not preload the full index: read the nearest local rules and target source/tests first, then fetch only the upstream guide(s) needed for the current choice.
