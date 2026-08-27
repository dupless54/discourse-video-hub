# Yeni ChatGPT / Work oturumu için prompt

`discourse-video-hub` repository'sinde çalışıyoruz. Önce root `AGENTS.md`, sonra `docs/ai/CURRENT_STATE.md` dosyasını oku ve context router'a göre yalnız görev için gerekli minimum dosyaları yükle.

Ürün sözleşmesi:
- Kullanıcılar yalnız herkese açık YouTube, TikTok ve Instagram video URL'leri paylaşır.
- Eklenti video metadata, profil vitrini, keşfet ve canonical watch page'i yönetir.
- Her video standart Topic + root Post ile eşlenir.
- Yorumlar core Nested Replies; video/yorum tepkileri Discourse Post/Reactions altyapısıdır.
- Ayrı comment, reaction, notification veya moderation gerçeği oluşturma.
- Core Discourse dosyalarını değiştirme.
- Provider fetch işlemlerini SSRF/network sınırı olarak ele al.
- Yetkilendirme ve görünürlük server-side Guardian üzerinden uygulanır.
- Frontend modern Glimmer `.gjs`, FormKit, Discourse tema değişkenleri ve safe escaped rendering kullanır.

Çalışma kuralları:
1. Non-trivial görevde task packet oluştur; goal/allowed paths/acceptance/validation/risk kilitli olsun.
2. Broad read öncesi T0-T3 effort tier seç.
3. `symbol/search -> targeted range -> dependency`; whole-repo preload yapma.
4. Source/tests stale dokümantasyondan üstündür.
5. Schema, SSRF, authorization, privacy, public contract, persistence ve cross-plugin sınırlarında context'i kontrollü genişlet.
6. Commit/push/PR/merge/rebase/reset/clean yalnız açık yetkiyle yapılır.
7. Builder kendi işini onaylayamaz.
8. Merge için Claude `READY`, bağımsız Codex `APPROVE`, Gemini `APPROVE`, exact paths, latest exact-head CI `GREEN` ve ayrıca açık kullanıcı merge onayı gerekir.
9. Reviewer/verifier anlaşmazlığında `NEEDS_HUMAN`; otomatik merge yoktur.
10. Yeni commit eski CI sonucunu geçersiz kılar; `NO_CI != GREEN`, `NOT_RUN != PASS`.
11. Testleri CI uğruna zayıflatma; unrelated scope/refactor ekleme.
12. Frontend AI context'i runtime asset klasörlerine koyma; `docs/ai/scopes/frontend/` kullan.

Yeni göreve repository state'ini fresh-read ederek başla. `CURRENT_STATE.md` history değildir; yalnız doğrulanmış mevcut durumu tut.
