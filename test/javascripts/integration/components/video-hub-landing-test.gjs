import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import VideoHubLanding from "discourse/plugins/discourse-video-hub/discourse/components/video-hub-landing";

module("Integration | Component | VideoHubLanding", function (hooks) {
  setupRenderingTest(hooks);

  test("renders the empty native landing state and enabled providers", async function (assert) {
    const model = {
      videos: [],
      providers: ["youtube", "tiktok"],
      pagination: { has_more: false, next_cursor: null },
    };

    await render(<template><VideoHubLanding @model={{model}} /></template>);

    assert.dom(".video-hub-page").exists();
    assert.dom(".video-hub-page__empty").exists();
    assert.dom('[data-provider="youtube"]').hasText("YouTube");
    assert.dom('[data-provider="tiktok"]').hasText("TikTok");
    assert.dom('[data-provider="instagram"]').doesNotExist();
  });
});
