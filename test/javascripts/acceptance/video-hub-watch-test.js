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

  function comment({ id, postNumber, username, text, replyCount = 0 }) {
    return {
      id,
      post_number: postNumber,
      username,
      cooked: `<p>${text}</p>`,
      reply_count: replyCount,
      actions_summary: [],
    };
  }

  test("loads the server payload and replaces a stale slug with the canonical watch path", async function (assert) {
    const topic = topicPayload();

    pretender.get("/videos/42/wrong-slug.json", () => response(videoPayload));
    pretender.get("/videos/42/canonical-video.json", () =>
      response(videoPayload)
    );
    pretender.get("/t/100.json", () => response(topic));
    pretender.get("/posts/101/replies.json", () => response([]));

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
    const firstComment = comment({
      id: 102,
      postNumber: 2,
      username: "alice",
      text: "First comment",
    });
    const secondComment = comment({
      id: 103,
      postNumber: 3,
      username: "bob",
      text: "New core comment",
    });
    let topic = topicPayload({ comments: [firstComment] });
    let rootComments = [firstComment];
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
    pretender.get("/posts/101/replies.json", (request) => {
      assert.strictEqual(request.queryParams.after, "1");
      return response(rootComments);
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

      rootComments = [firstComment, secondComment];
      topic = topicPayload({
        liked: true,
        likeCount: 4,
        comments: rootComments,
      });
      return response({ success: true, post: secondComment });
    });

    await visit("/videos/42/canonical-video");

    assert.dom('[data-post-id="102"]').hasText("alice First comment Reply");
    assert.dom(".video-hub-discussion__like").hasText("Like (3)");

    await click(".video-hub-discussion__like");

    assert.strictEqual(likeRequests, 1);
    assert.dom(".video-hub-discussion__like").hasText("Unlike (4)");

    await fillIn(
      '.video-hub-discussion__form textarea[name="raw"]',
      "A new comment"
    );
    await click('.video-hub-discussion__form button[type="submit"]');

    assert.strictEqual(commentRequests, 1);
    assert.dom('[data-post-id="103"]').hasText("bob New core comment Reply");
    assert.strictEqual(
      topicRequests,
      3,
      "reloads core topic after each mutation"
    );
  });

  test("paginates root comments and nested replies through core post replies", async function (assert) {
    const rootPage = Array.from({ length: 20 }, (_, index) =>
      comment({
        id: 102 + index,
        postNumber: 2 + index,
        username: `root-${index + 1}`,
        text: `Root comment ${index + 1}`,
        replyCount: index === 0 ? 21 : 0,
      })
    );
    const finalRootComment = comment({
      id: 122,
      postNumber: 22,
      username: "root-21",
      text: "Root comment 21",
    });
    const nestedPage = Array.from({ length: 20 }, (_, index) =>
      comment({
        id: 300 + index,
        postNumber: 100 + index,
        username: `nested-${index + 1}`,
        text: `Nested reply ${index + 1}`,
      })
    );
    const finalNestedReply = comment({
      id: 320,
      postNumber: 120,
      username: "nested-21",
      text: "Nested reply 21",
    });
    let nestedCreateRequests = 0;
    let nestedReloads = 0;

    pretender.get("/videos/42/canonical-video.json", () =>
      response(videoPayload)
    );
    pretender.get("/t/100.json", () => response(topicPayload()));
    pretender.get("/posts/101/replies.json", (request) => {
      if (request.queryParams.after === "1") {
        return response(rootPage);
      }

      assert.strictEqual(
        request.queryParams.after,
        "21",
        "root pagination advances from the last visible post number"
      );
      return response([finalRootComment]);
    });
    pretender.get("/posts/102/replies.json", (request) => {
      if (request.queryParams.after === "2") {
        nestedReloads += 1;
        return response(nestedPage);
      }

      assert.strictEqual(
        request.queryParams.after,
        "119",
        "nested pagination advances from the last direct reply"
      );
      return response([finalNestedReply]);
    });
    pretender.post("/posts.json", (request) => {
      nestedCreateRequests += 1;
      const params = new URLSearchParams(request.requestBody);

      assert.strictEqual(params.get("raw"), "Nested from the watch page");
      assert.strictEqual(params.get("topic_id"), "100");
      assert.strictEqual(
        params.get("reply_to_post_number"),
        "2",
        "targets the selected root comment"
      );

      return response({
        success: true,
        post: comment({
          id: 321,
          postNumber: 121,
          username: "current-user",
          text: "Nested from the watch page",
        }),
      });
    });

    await visit("/videos/42/canonical-video");

    assert.dom('[data-post-id="102"]').exists();
    assert.dom('[data-post-id="121"]').exists();
    assert
      .dom(".video-hub-discussion__load-more-comments")
      .hasText("Load more comments");

    await click('[data-post-id="102"] .video-hub-discussion__replies-toggle');

    assert.dom('[data-post-id="300"]').hasText("nested-1 Nested reply 1");
    assert
      .dom('[data-post-id="102"] .video-hub-discussion__replies-toggle')
      .hasText("Load more replies");

    await click('[data-post-id="102"] .video-hub-discussion__replies-toggle');

    assert.dom('[data-post-id="320"]').hasText("nested-21 Nested reply 21");

    await click(".video-hub-discussion__load-more-comments");

    assert.dom('[data-post-id="122"]').hasText("root-21 Root comment 21 Reply");
    assert.dom(".video-hub-discussion__load-more-comments").doesNotExist();

    await click('[data-reply-to-post-id="102"]');
    await fillIn(
      '[data-reply-form-post-id="102"] textarea[name="raw"]',
      "Nested from the watch page"
    );
    await click('[data-reply-form-post-id="102"] button[type="submit"]');

    assert.strictEqual(nestedCreateRequests, 1);
    assert.strictEqual(
      nestedReloads,
      2,
      "refreshes the selected comment replies after mutation"
    );
    assert.dom('[data-reply-form-post-id="102"]').doesNotExist();
  });
});
