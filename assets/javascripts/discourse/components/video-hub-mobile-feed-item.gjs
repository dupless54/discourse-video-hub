import Component from "@glimmer/component";
import { action } from "@ember/object";
import { on } from "@ember/modifier";
import DButton from "discourse/ui-kit/d-button";
import dObserveIntersection from "discourse/ui-kit/modifiers/d-observe-intersection";
import { i18n } from "discourse-i18n";
import VideoHubPlayer from "./video-hub-player";

const ACTIVE_THRESHOLD = 0.66;

export default class VideoHubMobileFeedItem extends Component {
  get isActive() {
    return this.args.video.id === this.args.activeVideoId;
  }

  get providerLabel() {
    return i18n(`video_hub.providers.${this.args.video.provider}`);
  }

  get previousDisabled() {
    return this.args.index <= 0;
  }

  get nextDisabled() {
    return this.args.index >= this.args.total - 1;
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

  @action
  onIntersection(entry) {
    const metricVisible =
      entry.isIntersecting && entry.intersectionRatio >= ACTIVE_THRESHOLD;

    this.args.onVisibilityChange?.(this.args.video.id, metricVisible);

    if (metricVisible) {
      this.args.onActivate?.(this.args.video.id, this.args.index);
    }
  }

  @action
  onKeydown(event) {
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
  previous() {
    this.navigate(this.args.index - 1);
  }

  @action
  next() {
    this.navigate(this.args.index + 1);
  }

  navigate(index) {
    if (index < 0 || index >= this.args.total) {
      return;
    }

    this.args.onNavigate?.(index);
  }

  <template>
    <article
      {{dObserveIntersection this.onIntersection threshold=ACTIVE_THRESHOLD}}
      {{on "keydown" this.onKeydown}}
      class={{this.itemClass}}
      data-video-hub-feed-index={{@index}}
      data-video-id={{@video.id}}
      data-active={{if this.isActive "true" "false"}}
      tabindex="0"
    >
      <VideoHubPlayer
        @video={{@video}}
        @active={{this.isActive}}
        @immersive={{@immersive}}
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

        <div class="video-hub-mobile-feed__controls">
          <DButton
            @action={{this.previous}}
            @disabled={{this.previousDisabled}}
            @icon="chevron-up"
            @label="video_hub.feed.previous"
            class="btn-small"
          />
          <DButton
            @action={{this.next}}
            @disabled={{this.nextDisabled}}
            @icon="chevron-down"
            @label="video_hub.feed.next"
            class="btn-small"
          />
        </div>
      </div>
    </article>
  </template>
}
