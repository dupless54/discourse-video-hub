import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { on } from "@ember/modifier";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import DButton from "discourse/ui-kit/d-button";
import dObserveIntersection from "discourse/ui-kit/modifiers/d-observe-intersection";
import { i18n } from "discourse-i18n";
import VideoHubDiscussion from "./video-hub-discussion";
import VideoHubPlayer from "./video-hub-player";

const ACTIVE_THRESHOLD = 0.66;

export default class VideoHubMobileFeedItem extends Component {
  @service currentUser;
  @service site;

  @tracked interactionMode = false;
  @tracked discussionOpen = false;
  @tracked topic = null;
  @tracked topicLoading = false;
  @tracked likeBusy = false;

  get isActive() {
    return this.args.video.id === this.args.activeVideoId;
  }

  get providerLabel() {
    return i18n(`video_hub.providers.${this.args.video.provider}`);
  }

  get itemClass() {
    const classes = ["video-hub-mobile-feed__item"];
    if (this.args.immersive) {
      classes.push("video-hub-mobile-feed__item--immersive");
    }
    return classes.join(" ");
  }

  get positionLabel() {
    return `${this.args.index + 1} / ${this.args.total}`;
  }

  get playerInteractive() {
    return Boolean(
      this.args.immersive && this.isActive && this.interactionMode
    );
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

  get likeDisabled() {
    return !this.currentUser || this.likeBusy || this.topicLoading;
  }

  get likeButtonLabel() {
    return i18n(
      this.liked ? "video_hub.watch.unlike" : "video_hub.watch.like",
      { count: this.likeCount }
    );
  }

  get likeButtonClass() {
    const classes = [
      "video-hub-mobile-feed__action",
      "video-hub-mobile-feed__action--like",
    ];
    if (this.liked) {
      classes.push("is-active");
    }
    return classes.join(" ");
  }

  get controlsButtonClass() {
    const classes = [
      "video-hub-mobile-feed__action",
      "video-hub-mobile-feed__action--controls",
    ];
    if (this.interactionMode) {
      classes.push("is-active");
    }
    return classes.join(" ");
  }

  @action
  onIntersection(entry) {
    const metricVisible =
      entry.isIntersecting && entry.intersectionRatio >= ACTIVE_THRESHOLD;

    this.args.onVisibilityChange?.(this.args.video.id, metricVisible);

    if (metricVisible) {
      this.args.onActivate?.(this.args.video.id, this.args.index);
      return;
    }

    this.interactionMode = false;
    this.discussionOpen = false;
  }

  @action
  onKeydown(event) {
    if (this.interactionMode || this.discussionOpen) {
      return;
    }

    let targetIndex = null;

    switch (event.key) {
      case "ArrowUp":
      case "PageUp":
        targetIndex = this.args.index - 1;
        break;
      case "ArrowDown":
      case "PageDown":
        targetIndex = this.args.index + 1;
        break;
      case "Home":
        targetIndex = 0;
        break;
      case "End":
        targetIndex = this.args.total - 1;
        break;
      default:
        return;
    }

    event.preventDefault();
    this.navigate(targetIndex);
  }

  @action
  toggleInteractionMode() {
    if (!this.args.immersive || !this.isActive) {
      return;
    }

    this.discussionOpen = false;
    this.interactionMode = !this.interactionMode;
  }

  @action
  async toggleLike() {
    if (!this.currentUser || this.likeBusy) {
      return;
    }

    const topic = await this.loadTopic();
    const summary = this.likeSummary;
    const rootPost = this.rootPost;

    if (
      !topic ||
      !summary ||
      !rootPost ||
      (!summary.acted && !summary.can_act)
    ) {
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

      await this.loadTopic({ force: true });
    } catch (error) {
      popupAjaxError(error);
    } finally {
      this.likeBusy = false;
    }
  }

  @action
  async openDiscussion() {
    this.interactionMode = false;
    const topic = await this.loadTopic();

    if (topic) {
      this.discussionOpen = true;
    }
  }

  @action
  closeDiscussion() {
    this.discussionOpen = false;
  }

  navigate(index) {
    if (index < 0 || index >= this.args.total) {
      return;
    }

    this.interactionMode = false;
    this.discussionOpen = false;
    this.args.onNavigate?.(index);
  }

  async loadTopic({ force = false } = {}) {
    if (this.topic && !force) {
      return this.topic;
    }

    if (this.topicLoading) {
      return null;
    }

    const topicId = this.args.video.topic_id;
    const postId = this.args.video.post_id;

    if (
      !Number.isSafeInteger(topicId) ||
      topicId <= 0 ||
      !Number.isSafeInteger(postId) ||
      postId <= 0
    ) {
      return null;
    }

    this.topicLoading = true;

    try {
      const topic = await ajax(`/t/${topicId}.json`);
      const rootPost = topic?.post_stream?.posts?.find(
        (post) => post.post_number === 1
      );

      if (topic?.id !== topicId || rootPost?.id !== postId) {
        throw new Error(
          "Video Hub explore topic mapping does not match Discourse"
        );
      }

      this.topic = topic;
      return topic;
    } catch (error) {
      popupAjaxError(error);
      return null;
    } finally {
      this.topicLoading = false;
    }
  }

  <template>
    <article
      {{dObserveIntersection this.onIntersection threshold=ACTIVE_THRESHOLD}}
      {{on "keydown" this.onKeydown}}
      class={{this.itemClass}}
      data-video-hub-feed-index={{@index}}
      data-video-id={{@video.id}}
      data-active={{if this.isActive "true" "false"}}
      data-controls-active={{if this.playerInteractive "true" "false"}}
      tabindex="0"
    >
      <VideoHubPlayer
        @video={{@video}}
        @active={{this.isActive}}
        @immersive={{@immersive}}
        @interactive={{this.playerInteractive}}
      />

      <div class="video-hub-mobile-feed__details">
        {{#if @immersive}}
          <span class="video-hub-mobile-feed__position" aria-hidden="true">
            {{this.positionLabel}}
          </span>
        {{/if}}

        <p class="video-hub-mobile-feed__provider">{{this.providerLabel}}</p>
        <h2>
          <a href={{@video.watch_path}}>{{@video.title}}</a>
        </h2>
        {{#if @video.author_name}}
          <p class="video-hub-mobile-feed__author">{{@video.author_name}}</p>
        {{/if}}

        {{#if @immersive}}
          <a
            class="video-hub-mobile-feed__watch-link"
            href={{@video.watch_path}}
          >
            {{i18n "video_hub.explore.open_video"}}
          </a>
        {{/if}}
      </div>

      {{#if @immersive}}
        <div
          class="video-hub-mobile-feed__actions"
          aria-label={{i18n "video_hub.watch.discussion_title"}}
        >
          <DButton
            @action={{this.toggleLike}}
            @disabled={{this.likeDisabled}}
            @icon="heart"
            @translatedLabel={{this.likeButtonLabel}}
            class={{this.likeButtonClass}}
          />
          <DButton
            @action={{this.openDiscussion}}
            @disabled={{this.topicLoading}}
            @icon="comment"
            @label="video_hub.watch.discussion_title"
            class="video-hub-mobile-feed__action video-hub-mobile-feed__action--comments"
          />
          <DButton
            @action={{this.toggleInteractionMode}}
            @icon="gear"
            @label="video_hub.watch.play_video"
            class={{this.controlsButtonClass}}
          />
        </div>
      {{/if}}

      {{#if this.discussionOpen}}
        <button
          type="button"
          class="video-hub-explore-comments__backdrop"
          aria-label={{i18n "video_hub.watch.reply_cancel"}}
          {{on "click" this.closeDiscussion}}
        ></button>
        <section
          class="video-hub-explore-comments"
          role="dialog"
          aria-modal="true"
          aria-label={{i18n "video_hub.watch.discussion_title"}}
        >
          <button
            type="button"
            class="video-hub-explore-comments__close"
            {{on "click" this.closeDiscussion}}
          >
            <span aria-hidden="true">×</span>
            <span class="sr-only">{{i18n "video_hub.watch.reply_cancel"}}</span>
          </button>
          <VideoHubDiscussion @video={{@video}} @topic={{this.topic}} />
        </section>
      {{/if}}
    </article>
  </template>
}
