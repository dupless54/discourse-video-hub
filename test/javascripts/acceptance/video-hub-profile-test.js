import { click, currentURL, fillIn, visit } from "@ember/test-helpers";
import { test } from "qunit";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

acceptance("Video Hub profile", function (needs) {
  needs.user({ can_edit: true });
  needs.settings({ video_hub_enabled: true });

  test("adds the Videos profile tab and renders ordered public profile sections", async function (assert) {
    let profileRequests = 0;

    pretender.get("/videos/profile/eviltrout.json", () => {
      profileRequests += 1;
      return response(publicProfileResponse());
    });

    await visit("/u/eviltrout/videos");

    assert.strictEqual(currentURL(), "/u/eviltrout/videos");
    assert.strictEqual(profileRequests, 1);
    assert.dom(".video-hub-profile-nav a").exists().hasText("Videos");
    assert.dom(".video-hub-profile__header h1").hasText("Videos");
    assert
      .dom('.video-hub-profile__manage[href="/u/eviltrout/videos/edit"]')
      .exists()
      .hasText("Manage layout");
    assert.dom(".video-hub-profile__section").exists({ count: 2 });
    assert
      .dom('.video-hub-profile__section[data-section-type="shorts"] h2')
      .hasText("Quick clips");
    assert
      .dom('.video-hub-profile__section[data-section-type="landscape"] h2')
      .hasText("Videos");
    assert.dom(".video-hub-card").exists({ count: 2 });
    assert
      .dom('.video-hub-card[data-kind="shorts"] h2')
      .hasText("Pinned short");
    assert.dom('.video-hub-card[href="/videos/102/wide-video"]').exists();
    assert
      .dom(".video-hub-profile__pin")
      .exists({ count: 1 })
      .hasText("Pinned");
  });

  test("renders a bounded empty state when the profile has no visible sections", async function (assert) {
    pretender.get("/videos/profile/eviltrout.json", () =>
      response({ profile: { username: "eviltrout", sections: [] } })
    );

    await visit("/u/eviltrout/videos");

    assert
      .dom(".video-hub-profile__empty")
      .hasText("There are no public videos on this profile yet.");
    assert.dom(".video-hub-card").doesNotExist();
  });

  test("edits existing layout records and submits a complete contiguous snapshot", async function (assert) {
    let layoutRequests = 0;
    let savedBody = "";

    stubEmptyCatalog();
    pretender.get("/videos/profile/eviltrout/layout.json", () => {
      layoutRequests += 1;
      return response(layoutResponse());
    });
    pretender.put("/videos/profile/eviltrout/layout.json", (request) => {
      savedBody = decodeURIComponent(request.requestBody.replaceAll("+", " "));
      return response({ profile: { username: "eviltrout", sections: [] } });
    });
    pretender.get("/videos/profile/eviltrout.json", () =>
      response(publicProfileResponse())
    );

    await visit("/u/eviltrout/videos/edit");

    assert.strictEqual(currentURL(), "/u/eviltrout/videos/edit");
    assert.strictEqual(layoutRequests, 1);
    assert.dom(".video-hub-profile-editor__section").exists({ count: 2 });
    assert.dom('[data-section-id="1"] [data-item-id]').exists({ count: 2 });

    await click(
      '[data-section-id="1"] .video-hub-profile-editor__section-move-down'
    );
    assert
      .dom(".video-hub-profile-editor__section:first-of-type")
      .hasAttribute("data-section-id", "2");

    await click(
      '[data-section-id="1"] [data-item-id="11"] .video-hub-profile-editor__item-move-down'
    );
    assert
      .dom('[data-section-id="1"] [data-item-id]:first-of-type')
      .hasAttribute("data-item-id", "13");

    await fillIn(
      '[data-section-id="1"] input[name$=".title"]',
      "Updated clips"
    );
    await click(
      '[data-section-id="1"] .video-hub-profile-editor__section-settings input[type="checkbox"]'
    );
    await click('[data-item-id="11"] input[name$=".pinned"]');
    await click(".video-hub-profile-editor__save");

    assert.strictEqual(currentURL(), "/u/eviltrout/videos");
    assert.true(savedBody.includes("layout[sections][0][id]=2"));
    assert.true(savedBody.includes("layout[sections][0][position]=0"));
    assert.true(savedBody.includes("layout[sections][1][id]=1"));
    assert.true(savedBody.includes("layout[sections][1][position]=1"));
    assert.true(savedBody.includes("layout[sections][1][title]=Updated clips"));
    assert.true(savedBody.includes("layout[sections][1][visible]=false"));
    assert.true(savedBody.includes("layout[sections][1][items][0][id]=13"));
    assert.true(
      savedBody.includes("layout[sections][1][items][0][position]=0")
    );
    assert.true(savedBody.includes("layout[sections][1][items][1][id]=11"));
    assert.true(
      savedBody.includes("layout[sections][1][items][1][position]=1")
    );
    assert.true(
      savedBody.includes("layout[sections][1][items][1][pinned]=false")
    );
  });

  test("adds and removes canonical videos while protecting dirty layout edits", async function (assert) {
    let added = false;
    let addRequests = 0;
    let removeRequests = 0;
    const candidate = videoPayload({
      id: 104,
      kind: "shorts",
      title: "Catalog short",
      thumbnailUrl: "https://example.com/catalog-short.jpg",
      watchPath: "/videos/104/catalog-short",
    });

    pretender.get("/videos/profile/eviltrout/layout.json", () =>
      response(
        added ? layoutResponseWithCandidate(candidate) : layoutResponse()
      )
    );
    pretender.get("/videos.json", () =>
      response({
        videos: [candidate],
        providers: ["youtube"],
        pagination: { has_more: false, next_cursor: null },
      })
    );
    pretender.put("/videos/profile/eviltrout/layout/videos/104.json", () => {
      addRequests += 1;
      added = true;
      return response(201, {
        membership: {
          username: "eviltrout",
          section_id: 1,
          section_type: "shorts",
          item_id: 14,
          video_id: 104,
          position: 2,
          pinned: false,
          visible: true,
        },
      });
    });
    pretender.delete("/videos/profile/eviltrout/layout/videos/104.json", () => {
      removeRequests += 1;
      added = false;
      return response(204);
    });

    await visit("/u/eviltrout/videos/edit");

    assert
      .dom('.video-hub-profile-editor__catalog-item[data-video-id="104"]')
      .exists();
    assert.dom(".video-hub-profile-editor__add-video").isNotDisabled();
    assert
      .dom('[data-item-id="11"] .video-hub-profile-editor__remove-video')
      .isNotDisabled();

    await fillIn(
      '[data-section-id="1"] input[name$=".title"]',
      "Unsaved title"
    );

    assert.dom(".video-hub-profile-editor__membership-lock-hint").exists();
    assert.dom(".video-hub-profile-editor__add-video").isDisabled();
    assert
      .dom('[data-item-id="11"] .video-hub-profile-editor__remove-video')
      .isDisabled();

    await click(".video-hub-profile-editor__reset");
    assert
      .dom(".video-hub-profile-editor__membership-lock-hint")
      .doesNotExist();
    assert.dom(".video-hub-profile-editor__add-video").isNotDisabled();

    await click(".video-hub-profile-editor__add-video");

    assert.strictEqual(addRequests, 1);
    assert
      .dom('.video-hub-profile-editor__catalog-item[data-video-id="104"]')
      .doesNotExist();
    assert
      .dom('[data-section-id="1"] [data-video-id="104"]')
      .exists()
      .hasAttribute("data-item-id", "14");

    await click(
      '[data-section-id="1"] [data-video-id="104"] .video-hub-profile-editor__remove-video'
    );

    assert.strictEqual(removeRequests, 1);
    assert.dom('[data-section-id="1"] [data-video-id="104"]').doesNotExist();
    assert
      .dom('.video-hub-profile-editor__catalog-item[data-video-id="104"]')
      .exists();
  });

  test("reloads the authoritative layout after a failed save", async function (assert) {
    let layoutRequests = 0;

    stubEmptyCatalog();
    pretender.get("/videos/profile/eviltrout/layout.json", () => {
      layoutRequests += 1;
      return response(layoutResponse());
    });
    pretender.put("/videos/profile/eviltrout/layout.json", () =>
      response(422, { error: { code: "invalid_layout" } })
    );

    await visit("/u/eviltrout/videos/edit");
    await fillIn(
      '[data-section-id="1"] input[name$=".title"]',
      "Unsaved client title"
    );
    assert.dom('[data-section-id="1"] h2').hasText("Unsaved client title");

    await click(".video-hub-profile-editor__save");

    assert.strictEqual(currentURL(), "/u/eviltrout/videos/edit");
    assert.strictEqual(layoutRequests, 2);
    assert.dom('[data-section-id="1"] h2').hasText("Quick clips");
  });
});

function stubEmptyCatalog() {
  pretender.get("/videos.json", () =>
    response({
      videos: [],
      providers: ["youtube"],
      pagination: { has_more: false, next_cursor: null },
    })
  );
}

function publicProfileResponse() {
  return {
    profile: {
      username: "eviltrout",
      sections: [
        {
          id: 1,
          section_type: "shorts",
          title: "Quick clips",
          position: 0,
          items: [
            {
              id: 11,
              position: 0,
              pinned: true,
              video: videoPayload({
                id: 101,
                kind: "shorts",
                title: "Pinned short",
                thumbnailUrl: "https://example.com/short.jpg",
                watchPath: "/videos/101/pinned-short",
              }),
            },
          ],
        },
        {
          id: 2,
          section_type: "landscape",
          title: null,
          position: 1,
          items: [
            {
              id: 12,
              position: 0,
              pinned: false,
              video: videoPayload({
                id: 102,
                kind: "landscape",
                title: "Wide video",
                thumbnailUrl: null,
                watchPath: "/videos/102/wide-video",
              }),
            },
          ],
        },
      ],
    },
  };
}

function layoutResponse() {
  return {
    profile: {
      username: "eviltrout",
      sections: [
        {
          id: 1,
          section_type: "shorts",
          title: "Quick clips",
          position: 0,
          visible: true,
          items: [
            {
              id: 11,
              video_id: 101,
              position: 0,
              pinned: true,
              visible: true,
              video: videoPayload({
                id: 101,
                kind: "shorts",
                title: "Pinned short",
                thumbnailUrl: "https://example.com/short.jpg",
                watchPath: "/videos/101/pinned-short",
              }),
            },
            {
              id: 13,
              video_id: 103,
              position: 1,
              pinned: false,
              visible: false,
              video: videoPayload({
                id: 103,
                kind: "shorts",
                title: "Hidden short",
                thumbnailUrl: null,
                watchPath: "/videos/103/hidden-short",
              }),
            },
          ],
        },
        {
          id: 2,
          section_type: "landscape",
          title: null,
          position: 1,
          visible: false,
          items: [
            {
              id: 12,
              video_id: 102,
              position: 0,
              pinned: false,
              visible: true,
              video: videoPayload({
                id: 102,
                kind: "landscape",
                title: "Wide video",
                thumbnailUrl: null,
                watchPath: "/videos/102/wide-video",
              }),
            },
          ],
        },
      ],
    },
  };
}

function layoutResponseWithCandidate(candidate) {
  const layout = layoutResponse();

  layout.profile.sections[0].items.push({
    id: 14,
    video_id: candidate.id,
    position: 2,
    pinned: false,
    visible: true,
    video: candidate,
  });

  return layout;
}

function videoPayload({ id, kind, title, thumbnailUrl, watchPath }) {
  return {
    id,
    provider: "youtube",
    external_id: `video-${id}`,
    canonical_url: `https://www.youtube.com/watch?v=video-${id}`,
    kind,
    title,
    thumbnail_url: thumbnailUrl,
    duration_seconds: 20,
    author_name: "Creator",
    topic_id: id + 100,
    post_id: id + 200,
    published_at: "2026-08-28T12:00:00Z",
    watch_path: watchPath,
  };
}
