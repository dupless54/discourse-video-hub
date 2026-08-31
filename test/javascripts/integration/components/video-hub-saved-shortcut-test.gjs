import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import VideoHubLanding from "discourse/plugins/discourse-video-hub/discourse/components/video-hub-landing";

const model = {
  videos: [],
  providers: [],
  pagination: { has_more: false, next_cursor: null },
};

module(
  "Integration | Component | VideoHubLanding | saved shortcut | anonymous",
  function (hooks) {
    setupRenderingTest(hooks, { anonymous: true });

    test("does not expose the private saved shortcut", async function (assert) {
      await render(<template><VideoHubLanding @model={{model}} /></template>);

      assert.dom(".video-hub-page__saved-link").doesNotExist();
    });
  }
);

module(
  "Integration | Component | VideoHubLanding | saved shortcut | authenticated",
  function (hooks) {
    setupRenderingTest(hooks);

    test("links authenticated viewers to their saved videos", async function (assert) {
      await render(<template><VideoHubLanding @model={{model}} /></template>);

      assert
        .dom(".video-hub-page__saved-link")
        .hasAttribute("href", "/videos/saved")
        .hasText("Saved videos");
    });
  }
);
