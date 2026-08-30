import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { trustHTML } from "@ember/template";
import Form from "discourse/components/form";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import DButton from "discourse/ui-kit/d-button";
import DDecoratedHtml from "discourse/ui-kit/d-decorated-html";
import { i18n } from "discourse-i18n";

export default class VideoHubDiscussion extends Component {
  @service currentUser;
  @service site;

  @tracked topic;
  @tracked likeBusy = false;
  @tracked commentData = { raw: "" };

  constructor(owner, args) {
    super(owner, args);
    this.topic = args.topic;
  }

  get rootPost() {
    return this.topic?.post_stream?.posts?.find(
      (post) => post.post_number === 1
    );
  }

  get comments() {
    return (
      this.topic?.post_stream?.posts?.filter((post) => post.post_number > 1) ||
      []
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

  @action
  async toggleLike() {
    const summary = this.likeSummary;
    const rootPost = this.rootPost;

    if (!this.canToggleLike || !summary || !rootPost || this.likeBusy) {
      return;
    }

    this.likeBusy = true;

    try {
      if (summary.acted) {
        await ajax(`/post_actions/${rootPost.id}`, {
          type: "DELETE",
          data: { post_action_type_id: summary.id },
        });
      } else {
        await ajax("/post_actions", {
          type: "POST",
          data: {
            id: rootPost.id,
            post_action_type_id: summary.id,
          },
        });
      }

      await this.reloadTopic();
    } catch (error) {
      popupAjaxError(error);
    } finally {
      this.likeBusy = false;
    }
  }

  @action
  async submitComment(data) {
    const raw = data.raw?.trim();

    if (!this.currentUser || !raw || !this.rootPost) {
      return;
    }

    try {
      await ajax("/posts.json", {
        type: "POST",
        data: {
          raw,
          topic_id: this.topic.id,
          reply_to_post_number: this.rootPost.post_number,
        },
      });

      this.commentData = { raw: "" };
      await this.reloadTopic();
    } catch (error) {
      popupAjaxError(error);
    }
  }

  async reloadTopic() {
    const topic = await ajax(`/t/${this.topic.id}.json`);
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
        {{#each this.comments as |comment|}}
          <article
            class="video-hub-discussion__comment"
            data-post-id={{comment.id}}
          >
            <header class="video-hub-discussion__comment-header">
              <strong>{{comment.username}}</strong>
            </header>
            <DDecoratedHtml
              @html={{trustHTML comment.cooked}}
              @model={{comment}}
              @className="cooked video-hub-discussion__cooked"
            />
          </article>
        {{else}}
          <p class="video-hub-discussion__empty">
            {{i18n "video_hub.watch.no_comments"}}
          </p>
        {{/each}}
      </div>
    </section>
  </template>
}
