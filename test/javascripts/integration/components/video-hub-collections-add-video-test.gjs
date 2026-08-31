import { click, findAll, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import VideoHubCollectionsManager from "discourse/plugins/discourse-video-hub/discourse/components/video-hub-collections-manager";

function collectionModel(overrides = {}) {
  return {
    collections: [
      {
        id: 42,
        collection_type: "playlist",
        title: "Favorites",
        description: null,
        position: 0,
        visible: false,
        items: [],
        ...overrides,
      },
    ],
  };
}

function catalogVideo(id, title) {
  return {
    id,
    provider: "youtube",
    external_id: `video-${id}`,
    canonical_url: `https://example.com/video-${id}`,
    kind: "landscape",
    title,
    thumbnail_url: null,
    duration_seconds: null,
    author_name: "Catalog creator",
    published_at: "2026-08-31T10:00:00Z",
    watch_path: `/videos/${id}/catalog-video-${id}`,
  };
}

module(
  "Integration | Component | VideoHubCollections add video",
  function (hooks) {
    setupRenderingTest(hooks);

    test("loads the catalog lazily, paginates without duplicates, and adds a canonical video", async function (assert) {
      let catalogRequests = 0;
      let addRequests = 0;

      pretender.get("/videos/collections/42/catalog.json", (request) => {
        catalogRequests += 1;

        if (request.queryParams.cursor === "90") {
          return response(200, {
            collection: { id: 42, collection_type: "playlist" },
            videos: [
              catalogVideo(91, "Already shown"),
              catalogVideo(90, "Second page"),
            ],
            pagination: { has_more: false, next_cursor: null },
          });
        }

        return response(200, {
          collection: { id: 42, collection_type: "playlist" },
          videos: [catalogVideo(91, "First page")],
          pagination: { has_more: true, next_cursor: "90" },
        });
      });

      pretender.put("/videos/collections/42/videos/90.json", () => {
        addRequests += 1;
        return response(201, {
          membership: {
            collection_id: 42,
            item_id: 500,
            video_id: 90,
            position: 0,
          },
        });
      });

      await render(
        <template>
          <VideoHubCollectionsManager @model={{collectionModel}} />
        </template>
      );

      assert.strictEqual(catalogRequests, 0, "catalog is lazy");

      await click(".video-hub-collections__catalog-toggle");

      assert.strictEqual(catalogRequests, 1);
      assert.dom('[data-catalog-video-id="91"]').exists();

      await click(".video-hub-collections__catalog-load-more");

      assert.strictEqual(catalogRequests, 2);
      assert.strictEqual(
        findAll('[data-catalog-video-id="91"]').length,
        1,
        "duplicate candidate ids are collapsed"
      );
      assert.dom('[data-catalog-video-id="90"]').exists();

      await click(
        '[data-catalog-video-id="90"] .video-hub-collections__catalog-add'
      );

      assert.strictEqual(addRequests, 1);
      assert.dom('[data-catalog-video-id="90"]').doesNotExist();
      assert.dom('[data-item-id="500"][data-video-id="90"]').exists();
      assert
        .dom('[data-video-id="90"] .video-hub-collections__item-copy strong')
        .hasText("Second page");
    });

    test("shows the owner-only series catalog explanation", async function (assert) {
      const model = collectionModel({
        collection_type: "series",
        title: "Episodes",
      });

      await render(
        <template><VideoHubCollectionsManager @model={{model}} /></template>
      );

      assert
        .dom(".video-hub-collections__catalog-copy")
        .hasText(/only your own canonical videos/i);
    });

    test("keeps the collection manager usable when catalog loading fails", async function (assert) {
      pretender.get("/videos/collections/42/catalog.json", () => response(500));

      await render(
        <template>
          <VideoHubCollectionsManager @model={{collectionModel}} />
        </template>
      );
      await click(".video-hub-collections__catalog-toggle");

      assert.dom(".video-hub-collections__catalog-retry").exists();
      assert.dom('[data-collection-id="42"] form').exists();
      assert.dom('[data-collection-id="42"] .btn-danger').exists();
    });
  }
);
