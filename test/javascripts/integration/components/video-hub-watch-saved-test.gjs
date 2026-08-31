import { click, render, settled } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import VideoHubWatch from "discourse/plugins/discourse-video-hub/discourse/components/video-hub-watch";

function watchModel({ saved = false, bookmarkId = null } = {}) {
  return {
    video: {
      id: 90,
      provider: "youtube",
      external_id: "dQw4w9WgXcQ",
      canonical_url: "https://www.youtube.com/watch?v=dQw4w9WgXcQ",
      kind: "landscape",
      title: "Saved state watch",
      thumbnail_url: null,
      author_name: "Creator",
      watch_path: "/videos/90/saved-state-watch",
      saved,
      bookmark_id: bookmarkId,
    },
  };
}

module(
  "Integration | Component | VideoHubWatch | anonymous saved state",
  function (hooks) {
    setupRenderingTest(hooks, { anonymous: true });

    test("does not expose the saved mutation control to anonymous viewers", async function (assert) {
      const model = watchModel({ saved: true, bookmarkId: 900 });

      await render(<template><VideoHubWatch @model={{model}} /></template>);

      assert.dom(".video-hub-watch__save").doesNotExist();
    });
  }
);

module(
  "Integration | Component | VideoHubWatch | saved state",
  function (hooks) {
    setupRenderingTest(hooks);

    test("toggles the canonical video through the saved mutation endpoints", async function (assert) {
      const model = watchModel();
      let saveRequests = 0;
      let unsaveRequests = 0;

      pretender.post("/videos/90/metrics", () => response({ recorded: true }));
      pretender.post("/videos/90/save", () => {
        saveRequests += 1;
        return response({ saved: true, bookmark_id: 901 });
      });
      pretender.delete("/videos/90/save", () => {
        unsaveRequests += 1;
        return response({ saved: false, bookmark_id: null });
      });

      await render(<template><VideoHubWatch @model={{model}} /></template>);
      await settled();

      assert.dom(".video-hub-watch__save").hasText("Save video");

      await click(".video-hub-watch__save");
      await settled();

      assert.strictEqual(saveRequests, 1);
      assert.dom(".video-hub-watch__save").hasText("Remove from saved");

      await click(".video-hub-watch__save");
      await settled();

      assert.strictEqual(unsaveRequests, 1);
      assert.dom(".video-hub-watch__save").hasText("Save video");
    });

    test("starts from the server-provided saved state", async function (assert) {
      const model = watchModel({ saved: true, bookmarkId: 902 });

      pretender.post("/videos/90/metrics", () => response({ recorded: true }));

      await render(<template><VideoHubWatch @model={{model}} /></template>);
      await settled();

      assert.dom(".video-hub-watch__save").hasText("Remove from saved");
    });
  }
);
