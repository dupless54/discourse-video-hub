import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import VideoHubWatch from "discourse/plugins/discourse-video-hub/discourse/components/video-hub-watch";

module("Integration | Component | VideoHubWatch", function (hooks) {
  setupRenderingTest(hooks);

  test("renders escaped provider metadata and a shorts placeholder", async function (assert) {
    const model = {
      video: {
        id: 7,
        provider: "tiktok",
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
      .exists("preserves the server-supplied video kind");
    assert.dom(".video-hub-watch__placeholder").hasText("TikTok");
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
  });
});
