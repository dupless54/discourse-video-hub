import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { trustHTML } from "@ember/template";
import Form from "discourse/components/form";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import DButton from "discourse/ui-kit/d-button";
import DDecoratedHtml from "discourse/ui-kit/d-decorated-html";
import { i18n } from "discourse-i18n";

const REPLIES_PAGE_SIZE = 20;

export default class VideoHubDiscussion extends Component {
  @service currentUser;
  @service site;

  @tracked topic;
  @tracked likeBusy = false;
  @tracked commentData = { raw: "" };
  @tracked commentItems = [];
  @tracked commentsLoaded = false;
  @tracked commentsLoading = false;
  @tracked commentsHasMore = false;
  @tracked replyData = { raw: "" };

  pendingRequests = new Map();

  constructor(owner, args) {
    super(owner, args);
    this.topic = args.topic;
    this.loadRootComments({ reset: true });
  }

  willDestroy() {
    this.cancelAllRequests();
    super.willDestroy();
  }

  get rootPost() {
    return this.topic?.post_stream?.posts?.find(
      (post) => post.post_number === 1
    );
  }

  get likeSummary() {
    return this.rootPost?.actions_summary?.find(
      (summary) => this.site.postActionTypeById(summary.id)?.name_key === "like"
    );
  }

  get likeCount() {
    return this.likeSummary?.count || 0;
  }

  get liked() {
    return Boolean(this.likeSummary?.acted);
  }

  get canToggleLike() {
    return Boolean(
      this.currentUser &&
      this.likeSummary &&
      (this.likeSummary.acted || this.likeSummary.can_act)
    );
  }

  get likeButtonLabel() {
    return i18n(
      this.liked ? "video_hub.watch.unlike" : "video_hub.watch.like",
      { count: this.likeCount }
    );
  }

  buildCommentItem(post, previous = null) {
    return {
      post,
      replies: previous?.replies || [],
      repliesLoaded: previous?.repliesLoaded || false,
      repliesLoading: false,
      repliesHasMore:
        previous?.repliesHasMore ??
        Boolean(post.reply_count && post.reply_count > 0),
      replyOpen: previous?.replyOpen || false,
    };
  }

  updateCommentItem(postId, changes) {
    this.commentItems = this.commentItems.map((item) =>
      item.post.id === postId ? { ...item, ...changes } : item
    );
  }

  startRequest(key, url, options) {
    this.pendingRequests.get(key)?.abort?.();

    const request = ajax(url, options);
    this.pendingRequests.set(key, request);
    return request;
  }

  isCurrentRequest(key, request) {
    return this.pendingRequests.get(key) === request;
  }

  finishRequest(key, request) {
    if (this.isCurrentRequest(key, request)) {
      this.pendingRequests.delete(key);
    }
  }

  cancelAllRequests() {
    for (const request of this.pendingRequests.values()) {
      request?.abort?.();
    }

    this.pendingRequests.clear();
  }

  isAbortError(error) {
    return error?.statusText === "abort" || error?.name === "AbortError";
  }

  async loadRootComments({ reset = false } = {}) {
    const rootPost = this.rootPost;

    if (!rootPost) {
      return;
    }

    if (
      !reset &&
      (this.commentsLoading || (this.commentsLoaded && !this.commentsHasMore))
    ) {
      return;
    }

    const after = reset
      ? rootPost.post_number
      : this.commentItems.at(-1)?.post.post_number || rootPost.post_number;
    const key = "root-comments";

    this.commentsLoading = true;
    const request = this.startRequest(
      key,
      `/posts/${rootPost.id}/replies.json?after=${after}`
    );

    try {
      const posts = await request;

      if (!this.isCurrentRequest(key, request)) {
        return;
      }

      if (!Array.isArray(posts)) {
        throw new Error("Video Hub root replies response must be an array");
      }

      if (reset) {
        const previousItems = new Map(
          this.commentItems.map((item) => [item.post.id, item])
        );

        this.commentItems = posts.map((post) =>
          this.buildCommentItem(post, previousItems.get(post.id))
        );
      } else {
        const existingIds = new Set(
          this.commentItems.map((item) => item.post.id)
        );
        const nextItems = posts
          .filter((post) => !existingIds.has(post.id))
          .map((post) => this.buildCommentItem(post));

        this.commentItems = [...this.commentItems, ...nextItems];
      }

      this.commentsLoaded = true;
      this.commentsHasMore = posts.length === REPLIES_PAGE_SIZE;
    } catch (error) {
      if (this.isCurrentRequest(key, request) && !this.isAbortError(error)) {
        popupAjaxError(error);
      }
    } finally {
      if (this.isCurrentRequest(key, request)) {
        this.commentsLoading = false;
        this.finishRequest(key, request);
      }
    }
  }

  async loadReplies(postId, { reset = false } = {}) {
    const item = this.commentItems.find(
      (commentItem) => commentItem.post.id === postId
    );

    if (!item) {
      return;
    }

    if (
      !reset &&
      (item.repliesLoading || (item.repliesLoaded && !item.repliesHasMore))
    ) {
      return;
    }

    const after = reset
      ? item.post.post_number
      : item.replies.at(-1)?.post_number || item.post.post_number;
    const key = `replies:${postId}`;

    this.updateCommentItem(postId, { repliesLoading: true });
    const request = this.startRequest(
      key,
      `/posts/${postId}/replies.json?after=${after}`
    );

    try {
      const replies = await request;

      if (!this.isCurrentRequest(key, request)) {
        return;
      }

      if (!Array.isArray(replies)) {
        throw new Error("Video Hub nested replies response must be an array");
      }

      const current = this.commentItems.find(
        (commentItem) => commentItem.post.id === postId
      );

      if (!current) {
        return;
      }

      let nextReplies;

      if (reset) {
        nextReplies = replies;
      } else {
        const existingIds = new Set(current.replies.map((reply) => reply.id));
        nextReplies = [
          ...current.replies,
          ...replies.filter((reply) => !existingIds.has(reply.id)),
        ];
      }

      this.updateCommentItem(postId, {
        replies: nextReplies,
        repliesLoaded: true,
        repliesLoading: false,
        repliesHasMore: replies.length === REPLIES_PAGE_SIZE,
      });
    } catch (error) {
      if (this.isCurrentRequest(key, request)) {
        this.updateCommentItem(postId, { repliesLoading: false });

        if (!this.isAbortError(error)) {
          popupAjaxError(error);
        }
      }
    } finally {
      this.finishRequest(key, request);
    }
  }

  @action
  loadMoreComments() {
    return this.loadRootComments();
  }

  @action
  loadMoreReplies(postId) {
    const item = this.commentItems.find(
      (commentItem) => commentItem.post.id === postId
    );

    return this.loadReplies(postId, { reset: !item?.repliesLoaded });
  }

  @action
  openReply(postId) {
    this.replyData = { raw: "" };
    this.commentItems = this.commentItems.map((item) => ({
      ...item,
      replyOpen: item.post.id === postId,
    }));
  }

  @action
  cancelReply() {
    this.replyData = { raw: "" };
    this.commentItems = this.commentItems.map((item) => ({
      ...item,
      replyOpen: false,
    }));
  }

  @action
  async toggleLike() {
    const summary = this.likeSummary;
    const rootPost = this.rootPost;

    if (!this.canToggleLike || !summary || !rootPost || this.likeBusy) {
      return;
    }

    this.likeBusy = true;
    const key = "like";
    const request = summary.acted
      ? this.startRequest(key, `/post_actions/${rootPost.id}`, {
          type: "DELETE",
          data: { post_action_type_id: summary.id },
        })
      : this.startRequest(key, "/post_actions", {
          type: "POST",
          data: {
            id: rootPost.id,
            post_action_type_id: summary.id,
          },
        });

    try {
      await request;

      if (!this.isCurrentRequest(key, request)) {
        return;
      }

      await this.reloadTopic();
    } catch (error) {
      if (!this.isAbortError(error)) {
        popupAjaxError(error);
      }
    } finally {
      this.likeBusy = false;
      this.finishRequest(key, request);
    }
  }

  @action
  async submitComment(data) {
    const raw = data.raw?.trim();

    if (!this.currentUser || !raw || !this.rootPost) {
      return;
    }

    const key = "comment-create";
    const request = this.startRequest(key, "/posts.json", {
      type: "POST",
      data: {
        raw,
        topic_id: this.topic.id,
        reply_to_post_number: this.rootPost.post_number,
      },
    });

    try {
      await request;

      if (!this.isCurrentRequest(key, request)) {
        return;
      }

      this.commentData = { raw: "" };
      await this.reloadTopic();
      await this.loadRootComments({ reset: true });
    } catch (error) {
      if (!this.isAbortError(error)) {
        popupAjaxError(error);
      }
    } finally {
      this.finishRequest(key, request);
    }
  }

  @action
  async submitReply(data) {
    const raw = data.raw?.trim();
    const target = this.commentItems.find((item) => item.replyOpen)?.post;

    if (!this.currentUser || !raw || !target) {
      return;
    }

    const key = `reply-create:${target.id}`;
    const request = this.startRequest(key, "/posts.json", {
      type: "POST",
      data: {
        raw,
        topic_id: this.topic.id,
        reply_to_post_number: target.post_number,
      },
    });

    try {
      await request;

      if (!this.isCurrentRequest(key, request)) {
        return;
      }

      this.replyData = { raw: "" };
      await this.reloadTopic();
      await this.loadReplies(target.id, { reset: true });
      this.commentItems = this.commentItems.map((item) => ({
        ...item,
        replyOpen: false,
      }));
    } catch (error) {
      if (!this.isAbortError(error)) {
        popupAjaxError(error);
      }
    } finally {
      this.finishRequest(key, request);
    }
  }

  async reloadTopic() {
    const key = "topic";
    const request = this.startRequest(key, `/t/${this.topic.id}.json`);

    try {
      const topic = await request;

      if (!this.isCurrentRequest(key, request)) {
        return;
      }

      const rootPost = topic?.post_stream?.posts?.find(
        (post) => post.post_number === 1
      );

      if (
        topic?.id !== this.args.video.topic_id ||
        rootPost?.id !== this.args.video.post_id
      ) {
        throw new Error("Video Hub topic mapping changed unexpectedly");
      }

      this.topic = topic;
    } finally {
      this.finishRequest(key, request);
    }
  }

  <template>
    <section
      class="video-hub-discussion"
      aria-labelledby="video-hub-discussion-title"
    >
      <header class="video-hub-discussion__header">
        <div>
          <p class="video-hub-discussion__eyebrow">
            {{i18n "video_hub.watch.discussion_eyebrow"}}
          </p>
          <h2 id="video-hub-discussion-title">
            {{i18n "video_hub.watch.discussion_title"}}
          </h2>
        </div>

        {{#if this.canToggleLike}}
          <DButton
            class="video-hub-discussion__like"
            @action={{this.toggleLike}}
            @disabled={{this.likeBusy}}
            @icon="heart"
            @translatedLabel={{this.likeButtonLabel}}
          />
        {{else}}
          <span class="video-hub-discussion__like-count">
            {{i18n "video_hub.watch.likes" count=this.likeCount}}
          </span>
        {{/if}}
      </header>

      {{#if this.currentUser}}
        <Form
          class="video-hub-discussion__form"
          @data={{this.commentData}}
          @onSubmit={{this.submitComment}}
          as |form|
        >
          <form.Field
            @name="raw"
            @title={{i18n "video_hub.watch.comment_label"}}
            @validation="required"
            @type="textarea"
            as |field|
          >
            <field.Control
              @placeholder={{i18n "video_hub.watch.comment_placeholder"}}
            />
          </form.Field>
          <form.Submit @label="video_hub.watch.comment_submit" />
        </Form>
      {{else}}
        <p class="video-hub-discussion__login-hint">
          {{i18n "video_hub.watch.login_to_interact"}}
        </p>
      {{/if}}

      <div class="video-hub-discussion__comments">
        {{#if this.commentsLoaded}}
          {{#each this.commentItems as |item|}}
            <article
              class="video-hub-discussion__comment"
              data-post-id={{item.post.id}}
            >
              <header class="video-hub-discussion__comment-header">
                <strong>{{item.post.username}}</strong>
              </header>
              <DDecoratedHtml
                @html={{trustHTML item.post.cooked}}
                @model={{item.post}}
                @className="cooked video-hub-discussion__cooked"
              />

              <div class="video-hub-discussion__comment-actions">
                {{#if this.currentUser}}
                  <DButton
                    class="video-hub-discussion__reply"
                    data-reply-to-post-id={{item.post.id}}
                    @action={{fn this.openReply item.post.id}}
                    @translatedLabel={{i18n "video_hub.watch.reply"}}
                  />
                {{/if}}

                {{#if item.repliesLoaded}}
                  {{#if item.repliesHasMore}}
                    <DButton
                      class="video-hub-discussion__replies-toggle"
                      @action={{fn this.loadMoreReplies item.post.id}}
                      @disabled={{item.repliesLoading}}
                      @translatedLabel={{i18n
                        "video_hub.watch.load_more_replies"
                      }}
                    />
                  {{/if}}
                {{else}}
                  {{#if item.post.reply_count}}
                    <DButton
                      class="video-hub-discussion__replies-toggle"
                      @action={{fn this.loadMoreReplies item.post.id}}
                      @disabled={{item.repliesLoading}}
                      @translatedLabel={{i18n
                        "video_hub.watch.show_replies"
                        count=item.post.reply_count
                      }}
                    />
                  {{/if}}
                {{/if}}
              </div>

              {{#if item.replyOpen}}
                <div
                  class="video-hub-discussion__reply-form-wrap"
                  data-reply-form-post-id={{item.post.id}}
                >
                  <Form
                    class="video-hub-discussion__reply-form"
                    @data={{this.replyData}}
                    @onSubmit={{this.submitReply}}
                    as |form|
                  >
                    <form.Field
                      @name="raw"
                      @title={{i18n
                        "video_hub.watch.reply_label"
                        username=item.post.username
                      }}
                      @validation="required"
                      @type="textarea"
                      as |field|
                    >
                      <field.Control
                        @placeholder={{i18n
                          "video_hub.watch.reply_placeholder"
                        }}
                      />
                    </form.Field>
                    <form.Submit @label="video_hub.watch.reply_submit" />
                    <DButton
                      class="video-hub-discussion__reply-cancel"
                      @action={{this.cancelReply}}
                      @translatedLabel={{i18n "video_hub.watch.reply_cancel"}}
                    />
                  </Form>
                </div>
              {{/if}}

              {{#if item.repliesLoaded}}
                <div class="video-hub-discussion__replies">
                  {{#each item.replies as |reply|}}
                    <article
                      class="video-hub-discussion__comment video-hub-discussion__nested-reply"
                      data-post-id={{reply.id}}
                    >
                      <header class="video-hub-discussion__comment-header">
                        <strong>{{reply.username}}</strong>
                      </header>
                      <DDecoratedHtml
                        @html={{trustHTML reply.cooked}}
                        @model={{reply}}
                        @className="cooked video-hub-discussion__cooked"
                      />
                    </article>
                  {{/each}}
                </div>
              {{/if}}
            </article>
          {{else}}
            <p class="video-hub-discussion__empty">
              {{i18n "video_hub.watch.no_comments"}}
            </p>
          {{/each}}

          {{#if this.commentsHasMore}}
            <DButton
              class="video-hub-discussion__load-more-comments"
              @action={{this.loadMoreComments}}
              @disabled={{this.commentsLoading}}
              @translatedLabel={{i18n "video_hub.watch.load_more_comments"}}
            />
          {{/if}}
        {{else}}
          <p class="video-hub-discussion__empty">
            {{i18n "video_hub.watch.loading_comments"}}
          </p>
        {{/if}}
      </div>
    </section>
  </template>
}
