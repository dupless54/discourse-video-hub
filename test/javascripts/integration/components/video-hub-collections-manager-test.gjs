import { click, fillIn, render, select } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import VideoHubCollectionsManager from "discourse/plugins/discourse-video-hub/discourse/components/video-hub-collections-manager";

module(
  "Integration | Component | VideoHubCollectionsManager",
  function (hooks) {
    setupRenderingTest(hooks);

    test("renders visible and unavailable memberships without autoplay metrics", async function (assert) {
      const model = {
        collections: [
          {
            id: 42,
            collection_type: "playlist",
            title: "Favorites",
            description: "My favorites",
            position: 0,
            visible: true,
            items: [
              {
                id: 400,
                video_id: 91,
                position: 0,
                video: {
                  id: 91,
                  provider: "youtube",
                  kind: "landscape",
                  title: "Visible video",
                  thumbnail_url: null,
                  author_name: "Visible creator",
                  watch_path: "/videos/91/visible-video",
                },
              },
              {
                id: 401,
                video_id: 92,
                position: 1,
                video: null,
              },
            ],
          },
        ],
      };
      let metricRequests = 0;

      pretender.post("/videos/91/metrics", () => {
        metricRequests += 1;
        return response({ recorded: true });
      });

      await render(
        <template><VideoHubCollectionsManager @model={{model}} /></template>
      );

      assert.dom('[data-collection-id="42"]').exists();
      assert
        .dom(
          '.video-hub-collections__public-link[href="/videos/collections/42"]'
        )
        .exists();
      assert
        .dom(
          '.video-hub-collections__item-preview[href="/videos/91/visible-video"]'
        )
        .hasText(/Visible video/);
      assert
        .dom('[data-video-id="92"] .video-hub-collections__item-copy strong')
        .hasText("Video unavailable");
      assert.dom(".video-hub-player__iframe").doesNotExist();
      assert.strictEqual(metricRequests, 0);
    });

    test("removes an unavailable membership without requiring hidden metadata", async function (assert) {
      const model = {
        collections: [
          {
            id: 42,
            collection_type: "playlist",
            title: "Private leftovers",
            description: null,
            position: 0,
            visible: false,
            items: [{ id: 401, video_id: 92, position: 0, video: null }],
          },
        ],
      };
      let requests = 0;

      pretender.delete("/videos/collections/42/videos/92.json", () => {
        requests += 1;
        return response(204);
      });

      await render(
        <template><VideoHubCollectionsManager @model={{model}} /></template>
      );
      await click('[data-video-id="92"] .video-hub-collections__remove-video');

      assert.strictEqual(requests, 1);
      assert.dom('[data-video-id="92"]').doesNotExist();
      assert.dom(".video-hub-collections__items-empty").exists();
    });

    test("creates a series through the existing collection API", async function (assert) {
      const model = { collections: [] };
      let requests = 0;
      let requestBody = "";

      pretender.post("/videos/collections.json", (request) => {
        requests += 1;
        requestBody = request.requestBody ?? "";
        return response(201, {
          collection: {
            id: 77,
            collection_type: "series",
            title: "My series",
            description: "Episodes",
            position: 0,
            visible: false,
            items: [],
          },
        });
      });

      await render(
        <template><VideoHubCollectionsManager @model={{model}} /></template>
      );
      await select(
        '.video-hub-collections__create [name="collection_type"]',
        "series"
      );
      await fillIn(
        '.video-hub-collections__create [name="title"]',
        "My series"
      );
      await fillIn(
        '.video-hub-collections__create [name="description"]',
        "Episodes"
      );
      await click('.video-hub-collections__create button[type="submit"]');

      assert.strictEqual(requests, 1);
      assert.true(requestBody.includes("collection_type=series"));
      assert.true(requestBody.includes("title=My+series"));
      assert.dom('[data-collection-id="77"]').exists();
      assert.dom('[data-collection-id="77"] h2').hasText("My series");
      assert
        .dom('[data-collection-id="77"] .video-hub-collections__public-link')
        .doesNotExist();
    });
  }
);
