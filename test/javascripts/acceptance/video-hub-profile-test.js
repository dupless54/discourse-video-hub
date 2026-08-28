import { currentURL, visit } from "@ember/test-helpers";
import { test } from "qunit";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

acceptance("Video Hub profile", function (needs) {
  needs.user();
  needs.settings({ video_hub_enabled: true });

  test("adds the Videos profile tab and renders ordered public profile sections", async function (assert) {
    let profileRequests = 0;
    let sections = [
      {
        id: 1,
        section_type: "shorts",
        title: "Quick clips",
        position: 0,
        items: [],
      },
    ];

    pretender.get("/videos/profile/eviltrout.json", () => {
      profileRequests += 1;
      return response({
        profile: {
          username: "eviltrout",
          sections,
        },
      });
    });

    await visit("/u/eviltrout/videos");
    // eslint-disable-next-line no-console
    console.warn("[video-hub diagnostic] section-only profile rendered");

    sections = [
      {
        id: 1,
        section_type: "shorts",
        title: "Quick clips",
        position: 0,
        items: [
          {
            id: 11,
            position: 0,
            pinned: false,
            video: {
              id: 101,
              provider: "youtube",
              external_id: "short-101",
              canonical_url: "https://www.youtube.com/watch?v=short-101",
              kind: "shorts",
              title: "Pinned short",
              thumbnail_url: "https://example.com/short.jpg",
              duration_seconds: 15,
              author_name: "Creator",
              topic_id: 201,
              post_id: 301,
              published_at: "2026-08-28T12:00:00Z",
              watch_path: "/videos/101/pinned-short",
            },
          },
        ],
      },
    ];

    await visit("/u/eviltrout");
    await visit("/u/eviltrout/videos");
    // eslint-disable-next-line no-console
    console.warn("[video-hub diagnostic] thumbnail item rendered");

    sections = [
      {
        id: 1,
        section_type: "shorts",
        title: "Quick clips",
        position: 0,
        items: [
          {
            id: 11,
            position: 0,
            pinned: true,
            video: {
              id: 101,
              provider: "youtube",
              external_id: "short-101",
              canonical_url: "https://www.youtube.com/watch?v=short-101",
              kind: "shorts",
              title: "Pinned short",
              thumbnail_url: null,
              duration_seconds: 15,
              author_name: "Creator",
              topic_id: 201,
              post_id: 301,
              published_at: "2026-08-28T12:00:00Z",
              watch_path: "/videos/101/pinned-short",
            },
          },
        ],
      },
    ];

    await visit("/u/eviltrout");
    await visit("/u/eviltrout/videos");
    // eslint-disable-next-line no-console
    console.warn("[video-hub diagnostic] placeholder pinned item rendered");

    sections = [
      {
        id: 1,
        section_type: "shorts",
        title: "Quick clips",
        position: 0,
        items: [
          {
            id: 11,
            position: 0,
            pinned: true,
            video: {
              id: 101,
              provider: "youtube",
              external_id: "short-101",
              canonical_url: "https://www.youtube.com/watch?v=short-101",
              kind: "shorts",
              title: "Pinned short",
              thumbnail_url: "https://example.com/short.jpg",
              duration_seconds: 15,
              author_name: "Creator",
              topic_id: 201,
              post_id: 301,
              published_at: "2026-08-28T12:00:00Z",
              watch_path: "/videos/101/pinned-short",
            },
          },
        ],
      },
      {
        id: 2,
        section_type: "landscape",
        title: null,
        position: 1,
        items: [
          {
            id: 12,
            position: 0,
            pinned: false,
            video: {
              id: 102,
              provider: "youtube",
              external_id: "wide-102",
              canonical_url: "https://www.youtube.com/watch?v=wide-102",
              kind: "landscape",
              title: "Wide video",
              thumbnail_url: null,
              duration_seconds: null,
              author_name: "Creator",
              topic_id: 202,
              post_id: 302,
              published_at: "2026-08-28T11:00:00Z",
              watch_path: "/videos/102/wide-video",
            },
          },
        ],
      },
    ];

    await visit("/u/eviltrout");
    await visit("/u/eviltrout/videos");
    // eslint-disable-next-line no-console
    console.warn("[video-hub diagnostic] full populated profile rendered");

    assert.strictEqual(currentURL(), "/u/eviltrout/videos");
    assert.strictEqual(profileRequests, 4);
    assert.dom(".video-hub-profile-nav a").exists().hasText("Videos");
    assert.dom(".video-hub-profile__header h1").hasText("Videos");
    assert.dom(".video-hub-profile__section").exists({ count: 2 });
    assert
      .dom('.video-hub-profile__section[data-section-type="shorts"] h2')
      .hasText("Quick clips");
    assert
      .dom('.video-hub-profile__section[data-section-type="landscape"] h2')
      .hasText("Videos");
    assert.dom(".video-hub-card").exists({ count: 2 });
    assert.dom('.video-hub-card[data-kind="shorts"]').hasText("Pinned short");
    assert.dom('.video-hub-card[href="/videos/102/wide-video"]').exists();
    assert
      .dom(".video-hub-profile__pin")
      .exists({ count: 1 })
      .hasText("Pinned");
  });

  test("renders a bounded empty state when the profile has no visible sections", async function (assert) {
    pretender.get("/videos/profile/eviltrout.json", () =>
      response({ profile: { username: "eviltrout", sections: [] } })
    );

    await visit("/u/eviltrout/videos");

    assert
      .dom(".video-hub-profile__empty")
      .hasText("There are no public videos on this profile yet.");
    assert.dom(".video-hub-card").doesNotExist();
  });
});
