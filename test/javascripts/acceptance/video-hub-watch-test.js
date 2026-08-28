import { click, currentURL, fillIn, visit } from "@ember/test-helpers";
import { test } from "qunit";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

acceptance("Video Hub canonical watch", function (needs) {
  needs.user();

  const videoPayload = {
    video: {
      id: 42,
      provider: "youtube",
      external_id: "dQw4w9WgXcQ",
      canonical_url: "https://www.youtube.com/watch?v=dQw4w9WgXcQ",
      kind: "landscape",
      title: "Canonical video",
      thumbnail_url: "https://i.ytimg.com/vi/dQw4w9WgXcQ/hqdefault.jpg",
      duration_seconds: null,
      author_name: "Example creator",
      topic_id: 100,
      post_id: 101,
      published_at: "2026-08-28T12:00:00Z",
      watch_path: "/videos/42/canonical-video",
    },
  };

  function topicPayload({ liked = false, likeCount = 3, comments = [] } = {}) {
    return {
      id: 100,
      post_stream: {
        posts: [
          {
            id: 101,
            post_number: 1,
            username: "video-owner",
            cooked: "<p>Video root post</p>",
            actions_summary: [
              {
                id: 2,
                count: likeCount,
                acted: liked,
                can_act: !liked,
                can_undo: liked,
              },
            ],
          },
          ...comments,
        ],
      },
    };
  }

  test("loads the server payload and replaces a stale slug with the canonical watch path", async function (assert) {
    const topic = topicPayload();

    pretender.get("/videos/42/wrong-slug.json", () => response(videoPayload));
    pretender.get("/videos/42/canonical-video.json", () =>
      response(videoPayload)
    );
    pretender.get("/t/100.json", () => response(topic));

    await visit("/videos/42/wrong-slug");

    assert.strictEqual(currentURL(), "/videos/42/canonical-video");
    assert.dom(".video-hub-watch__details h1").hasText("Canonical video");
    assert.dom(".video-hub-watch__author").hasText("Example creator");
    assert
      .dom(".video-hub-watch__media img")
      .hasAttribute("src", "https://i.ytimg.com/vi/dQw4w9WgXcQ/hqdefault.jpg")
      .hasAttribute("alt", "Canonical video");
    assert
      .dom(".video-hub-watch__provider-link")
      .hasAttribute("href", "https://www.youtube.com/watch?v=dQw4w9WgXcQ")
      .hasText("Watch on YouTube");
    assert.dom(".video-hub-discussion").exists();
  });

  test("uses core post actions and posts for likes and comments", async function (assert) {
    const firstComment = {
      id: 102,
      post_number: 2,
      username: "alice",
      cooked: "<p>First comment</p>",
      actions_summary: [],
    };
    const secondComment = {
      id: 103,
      post_number: 3,
      username: "bob",
      cooked: "<p>New core comment</p>",
      actions_summary: [],
    };
    let topic = topicPayload({ comments: [firstComment] });
    let topicRequests = 0;
    let likeRequests = 0;
    let commentRequests = 0;

    pretender.get("/videos/42/canonical-video.json", () =>
      response(videoPayload)
    );
    pretender.get("/t/100.json", () => {
      topicRequests += 1;
      return response(topic);
    });
    pretender.post("/post_actions", (request) => {
      likeRequests += 1;
      const params = new URLSearchParams(request.requestBody);

      assert.strictEqual(params.get("id"), "101", "targets the root post");
      assert.strictEqual(
        params.get("post_action_type_id"),
        "2",
        "uses the core like action type"
      );

      topic = topicPayload({
        liked: true,
        likeCount: 4,
        comments: [firstComment],
      });
      return response({ result: [] });
    });
    pretender.post("/posts.json", (request) => {
      commentRequests += 1;
      const params = new URLSearchParams(request.requestBody);

      assert.strictEqual(params.get("raw"), "A new comment");
      assert.strictEqual(params.get("topic_id"), "100");
      assert.strictEqual(
        params.get("reply_to_post_number"),
        "1",
        "replies to the canonical video root post"
      );

      topic = topicPayload({
        liked: true,
        likeCount: 4,
        comments: [firstComment, secondComment],
      });
      return response({ success: true, post: secondComment });
    });

    await visit("/videos/42/canonical-video");

    assert.dom('[data-post-id="102"]').hasText("alice First comment");
    assert.dom(".video-hub-discussion__like").hasText("Like (3)");

    await click(".video-hub-discussion__like");

    assert.strictEqual(likeRequests, 1);
    assert.dom(".video-hub-discussion__like").hasText("Unlike (4)");

    await fillIn('textarea[name="raw"]', "A new comment");
    await click('.video-hub-discussion__form button[type="submit"]');

    assert.strictEqual(commentRequests, 1);
    assert.dom('[data-post-id="103"]').hasText("bob New core comment");
    assert.strictEqual(
      topicRequests,
      3,
      "reloads core topic after each mutation"
    );
  });
});
