import { click, render, settled } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import VideoHubWatch from "discourse/plugins/discourse-video-hub/discourse/components/video-hub-watch";

module("Integration | Component | VideoHubWatch", function (hooks) {
  setupRenderingTest(hooks, { anonymous: true });

  test("keeps TikTok lazy until user activation and renders escaped metadata", async function (assert) {
    const model = {
      video: {
        id: 7,
        provider: "tiktok",
        external_id: "1234567890",
        canonical_url: "https://www.tiktok.com/@creator/video/1234567890",
        kind: "shorts",
        title: "Literal <strong>title</strong>",
        thumbnail_url: null,
        author_name: null,
        watch_path: "/videos/7/literal-title",
      },
    };

    await render(<template><VideoHubWatch @model={{model}} /></template>);

    assert.dom(".video-hub-watch").exists();
    assert
      .dom('.video-hub-watch__media[data-kind="shorts"]')
      .hasAttribute("data-provider", "tiktok");
    assert.dom(".video-hub-watch__placeholder").hasText("TikTok");
    assert.dom(".video-hub-player__iframe").doesNotExist();
    assert.dom(".video-hub-player__play").hasText("Play video");
    assert
      .dom(".video-hub-watch__details h1")
      .hasText("Literal <strong>title</strong>");
    assert
      .dom(".video-hub-watch__details h1 strong")
      .doesNotExist("does not render provider text as HTML");
    assert.dom(".video-hub-watch__author").doesNotExist();
    assert
      .dom(".video-hub-watch__provider-link")
      .hasAttribute("href", "https://www.tiktok.com/@creator/video/1234567890")
      .hasAttribute("target", "_blank")
      .hasAttribute("rel", "noopener noreferrer nofollow")
      .hasText("Watch on TikTok");

    await click(".video-hub-player__play");

    assert
      .dom(".video-hub-player__iframe")
      .hasAttribute(
        "src",
        "https://www.tiktok.com/player/v1/1234567890?autoplay=1"
      )
      .hasAttribute("title", "TikTok video player")
      .hasAttribute("referrerpolicy", "strict-origin-when-cross-origin");
    assert.dom(".video-hub-watch__placeholder").doesNotExist();
  });

  test("constructs a YouTube iframe only from a validated video id", async function (assert) {
    const model = {
      video: {
        id: 8,
        provider: "youtube",
        external_id: "dQw4w9WgXcQ",
        canonical_url: "https://www.youtube.com/watch?v=dQw4w9WgXcQ",
        kind: "landscape",
        title: "YouTube video",
        thumbnail_url: "https://i.ytimg.com/vi/dQw4w9WgXcQ/hqdefault.jpg",
        author_name: "Creator",
        watch_path: "/videos/8/youtube-video",
      },
    };

    await render(<template><VideoHubWatch @model={{model}} /></template>);

    assert.dom(".video-hub-player__iframe").doesNotExist();
    assert
      .dom(".video-hub-watch__media img")
      .hasAttribute("src", "https://i.ytimg.com/vi/dQw4w9WgXcQ/hqdefault.jpg")
      .hasAttribute("alt", "YouTube video");

    await click(".video-hub-player__play");

    assert
      .dom(".video-hub-player__iframe")
      .hasAttribute(
        "src",
        "https://www.youtube.com/embed/dQw4w9WgXcQ?autoplay=1"
      )
      .hasAttribute("title", "YouTube video player");
  });

  test("keeps Instagram on the safe external-provider fallback", async function (assert) {
    const model = {
      video: {
        id: 9,
        provider: "instagram",
        external_id: "AbCdEf123",
        canonical_url: "https://www.instagram.com/reel/AbCdEf123/",
        kind: "shorts",
        title: "Instagram reel",
        thumbnail_url: null,
        author_name: "Creator",
        watch_path: "/videos/9/instagram-reel",
      },
    };

    await render(<template><VideoHubWatch @model={{model}} /></template>);

    assert.dom(".video-hub-player__iframe").doesNotExist();
    assert.dom(".video-hub-player__play").doesNotExist();
    assert.dom(".video-hub-watch__placeholder").hasText("Instagram");
    assert
      .dom(".video-hub-watch__provider-link")
      .hasAttribute("href", "https://www.instagram.com/reel/AbCdEf123/");
  });

  test("fails closed when a provider id is not valid for its player", async function (assert) {
    const model = {
      video: {
        id: 10,
        provider: "youtube",
        external_id: "dQw4w9WgXcQ?evil=1",
        canonical_url: "https://www.youtube.com/watch?v=dQw4w9WgXcQ",
        kind: "landscape",
        title: "Invalid player id",
        thumbnail_url: null,
        author_name: null,
        watch_path: "/videos/10/invalid-player-id",
      },
    };

    await render(<template><VideoHubWatch @model={{model}} /></template>);

    assert.dom(".video-hub-player__iframe").doesNotExist();
    assert.dom(".video-hub-player__play").doesNotExist();
    assert
      .dom(".video-hub-watch__provider-link")
      .hasAttribute("href", "https://www.youtube.com/watch?v=dQw4w9WgXcQ");
  });

  test("does not send canonical metrics for an anonymous viewer", async function (assert) {
    let requestCount = 0;
    const model = {
      video: {
        id: 11,
        provider: "youtube",
        external_id: "dQw4w9WgXcQ",
        canonical_url: "https://www.youtube.com/watch?v=dQw4w9WgXcQ",
        kind: "landscape",
        title: "Anonymous watch",
        thumbnail_url: null,
        author_name: null,
        watch_path: "/videos/11/anonymous-watch",
      },
    };

    pretender.post("/videos/11/metrics", () => {
      requestCount += 1;
      return response({ recorded: true });
    });

    await render(<template><VideoHubWatch @model={{model}} /></template>);
    await settled();

    assert.strictEqual(requestCount, 0);
  });
});

module(
  "Integration | Component | VideoHubWatch | authenticated metrics",
  function (hooks) {
    setupRenderingTest(hooks);

    test("records one canonical impression and qualified view after dwell", async function (assert) {
      const requestBodies = [];
      const model = {
        video: {
          id: 12,
          provider: "youtube",
          external_id: "dQw4w9WgXcQ",
          canonical_url: "https://www.youtube.com/watch?v=dQw4w9WgXcQ",
          kind: "landscape",
          title: "Authenticated watch",
          thumbnail_url: null,
          author_name: "Creator",
          watch_path: "/videos/12/authenticated-watch",
        },
      };

      pretender.post("/videos/12/metrics", (request) => {
        requestBodies.push(request.requestBody ?? "");
        return response({ recorded: true });
      });

      await render(<template><VideoHubWatch @model={{model}} /></template>);
      await settled();

      assert.strictEqual(requestBodies.length, 2);
      assert.true(requestBodies[0].includes("impression"));
      assert.true(requestBodies[1].includes("qualified_view"));
    });
  }
);
