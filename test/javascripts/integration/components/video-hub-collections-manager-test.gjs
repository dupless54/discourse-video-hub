import {
  click,
  fillIn,
  findAll,
  render,
  select,
} from "@ember/test-helpers";
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

      const params = new URLSearchParams(requestBody);

      assert.strictEqual(requests, 1);
      assert.strictEqual(params.get("collection[collection_type]"), "series");
      assert.strictEqual(params.get("collection[title]"), "My series");
      assert.strictEqual(params.get("collection[description]"), "Episodes");
      assert.dom('[data-collection-id="77"]').exists();
      assert.dom('[data-collection-id="77"] h2').hasText("My series");
      assert
        .dom('[data-collection-id="77"] .video-hub-collections__public-link')
        .doesNotExist();
    });

    test("reorders collections and memberships through authoritative server permutations", async function (assert) {
      const model = {
        collections: [
          {
            id: 10,
            collection_type: "playlist",
            title: "First",
            description: null,
            position: 0,
            visible: false,
            items: [],
          },
          {
            id: 20,
            collection_type: "playlist",
            title: "Second",
            description: null,
            position: 1,
            visible: false,
            items: [
              {
                id: 201,
                video_id: 91,
                position: 0,
                video: {
                  id: 91,
                  provider: "youtube",
                  title: "First item",
                  thumbnail_url: null,
                  author_name: "Creator",
                  watch_path: "/videos/91/first-item",
                },
              },
              {
                id: 202,
                video_id: 92,
                position: 1,
                video: {
                  id: 92,
                  provider: "youtube",
                  title: "Second item",
                  thumbnail_url: null,
                  author_name: "Creator",
                  watch_path: "/videos/92/second-item",
                },
              },
            ],
          },
        ],
      };
      let collectionOrder = [];
      let itemOrder = [];

      pretender.put("/videos/collections/reorder.json", (request) => {
        const params = new URLSearchParams(request.requestBody ?? "");
        collectionOrder = params.getAll("collection_ids[]").map(Number);
        return response({ collection_ids: [20, 10] });
      });
      pretender.put("/videos/collections/20/items/reorder.json", (request) => {
        const params = new URLSearchParams(request.requestBody ?? "");
        itemOrder = params.getAll("item_ids[]").map(Number);
        return response({ item_ids: [202, 201] });
      });

      await render(
        <template><VideoHubCollectionsManager @model={{model}} /></template>
      );

      assert
        .dom('[data-collection-id="10"] .video-hub-collections__collection-move-up')
        .isDisabled();
      assert
        .dom('[data-collection-id="20"] .video-hub-collections__collection-move-down')
        .isDisabled();

      await click(
        '[data-collection-id="20"] .video-hub-collections__collection-move-up'
      );

      assert.deepEqual(collectionOrder, [20, 10]);
      assert.deepEqual(
        findAll("[data-collection-id]").map((element) =>
          Number(element.dataset.collectionId)
        ),
        [20, 10]
      );

      await click(
        '[data-collection-id="20"] [data-item-id="202"] .video-hub-collections__item-move-up'
      );

      assert.deepEqual(itemOrder, [202, 201]);
      assert.deepEqual(
        findAll('[data-collection-id="20"] [data-item-id]').map((element) =>
          Number(element.dataset.itemId)
        ),
        [202, 201]
      );
      assert
        .dom(
          '[data-collection-id="20"] [data-item-id="202"] .video-hub-collections__item-move-up'
        )
        .isDisabled();
    });
  }
);
