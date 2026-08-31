import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import VideoHubCollection from "discourse/plugins/discourse-video-hub/discourse/components/video-hub-collection";

module("Integration | Component | VideoHubCollection", function (hooks) {
  setupRenderingTest(hooks, { anonymous: true });

  test("renders public collection metadata and canonical video cards without autoplay metrics", async function (assert) {
    const model = {
      collection: {
        id: 42,
        collection_type: "series",
        title: "Creator series",
        description: "A visible creator series",
        owner: {
          id: 7,
          username: "collection-owner",
          name: "Collection Owner",
        },
        items: [
          {
            position: 0,
            video: {
              id: 91,
              provider: "youtube",
              kind: "landscape",
              title: "Series episode",
              thumbnail_url: null,
              author_name: "Collection creator",
              watch_path: "/videos/91/series-episode",
            },
          },
        ],
      },
    };
    let metricRequests = 0;

    pretender.post("/videos/91/metrics", () => {
      metricRequests += 1;
      return response({ recorded: true });
    });

    await render(<template><VideoHubCollection @model={{model}} /></template>);

    assert.dom(".video-hub-collection h1").hasText("Creator series");
    assert.dom(".video-hub-collection__type").hasText("Series");
    assert.dom(".video-hub-collection__meta").includesText("1 video");
    assert
      .dom(".video-hub-collection__owner")
      .hasAttribute("href", "/u/collection-owner/videos")
      .hasText("Curated by @collection-owner");
    assert.dom(".video-hub-card").exists({ count: 1 });
    assert
      .dom(".video-hub-card")
      .hasAttribute("href", "/videos/91/series-episode");
    assert.dom(".video-hub-mobile-feed").doesNotExist();
    assert.dom(".video-hub-player__iframe").doesNotExist();
    assert.strictEqual(metricRequests, 0);
  });

  test("renders a bounded empty collection state", async function (assert) {
    const model = {
      collection: {
        id: 43,
        collection_type: "playlist",
        title: "Empty playlist",
        description: null,
        owner: {
          id: 8,
          username: "empty-owner",
          name: "Empty Owner",
        },
        items: [],
      },
    };

    await render(<template><VideoHubCollection @model={{model}} /></template>);

    assert.dom(".video-hub-collection__empty").exists();
    assert.dom(".video-hub-card").doesNotExist();
    assert.dom(".video-hub-collection__type").hasText("Playlist");
  });
});
