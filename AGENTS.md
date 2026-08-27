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

## Delivery governance
- Goal, allowed paths, acceptance ve validation task packet içinde kilitlenir.
- Unrelated refactor veya dependency ekleme yapılmaz.
- Commit/push/PR update/rebase/merge/reset/clean yalnız görevde açıkça yetkilendirilirse yapılır.
- Builder kendi işini onaylayamaz.
- Merge gate: Claude `READY` + bağımsız Codex `APPROVE` + Gemini final `APPROVE` + exact-path validation + latest exact PR head CI `GREEN` + kullanıcının açık merge yetkisi.
- Reviewer/verifier anlaşmazlığı çözülmezse `NEEDS_HUMAN`; otomatik uzlaşma veya merge yoktur.
- Yeni commit eski CI kanıtını geçersiz kılar. `NO_CI != GREEN`, `NOT_RUN != PASS`.
- Testleri yalnız CI yeşili için zayıflatma. CI repair en fazla 3 bounded tur; sonra `NEEDS_HUMAN`.

## Runtime asset guardrail
AI context dosyalarını runtime-compiled klasörlere koyma. Özellikle `assets/javascripts/{AGENTS,CLAUDE,GEMINI}.md` kullanma. Frontend context `docs/ai/scopes/frontend/` altında kalır.

## Platform adapters
`CLAUDE.md`, `GEMINI.md`, `.claude/` ve `.codex/` canonical kuralları tekrar etmez; bu dosyaya ve `EFFORT_ROUTER.md`'ye yönlendirir.
