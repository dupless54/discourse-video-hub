import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { LinkTo } from "@ember/routing";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import DButton from "discourse/ui-kit/d-button";
import { i18n } from "discourse-i18n";
import VideoHubCard from "./video-hub-card";

export default class VideoHubTrending extends Component {
  @tracked videos = [];
  @tracked pagination = { has_more: false, next_cursor: null };
  @tracked loadingMore = false;

  constructor() {
    super(...arguments);
    this.videos = [...(this.args.model.videos ?? [])];
    this.pagination = this.normalizePagination(this.args.model.pagination);
  }

  get canLoadMore() {
    return Boolean(
      this.pagination.has_more &&
      this.pagination.next_cursor &&
      !this.loadingMore
    );
  }

  get showLoadMore() {
    return this.canLoadMore || this.loadingMore;
  }

  normalizePagination(pagination) {
    return {
      has_more: Boolean(pagination?.has_more),
      next_cursor:
        typeof pagination?.next_cursor === "string"
          ? pagination.next_cursor
          : null,
    };
  }

  @action
  async loadMore() {
    if (!this.canLoadMore) {
      return;
    }

    const cursor = this.pagination.next_cursor;
    this.loadingMore = true;

    try {
      const response = await ajax("/videos/trending/feed.json", {
        data: { cursor },
      });
      const incomingVideos = Array.isArray(response?.videos)
        ? response.videos
        : [];
      const existingIds = new Set(this.videos.map((video) => video.id));

      this.videos = [
        ...this.videos,
        ...incomingVideos.filter((video) => !existingIds.has(video.id)),
      ];
      this.pagination = this.normalizePagination(response?.pagination);
    } catch (error) {
      popupAjaxError(error);
    } finally {
      this.loadingMore = false;
    }
  }

  <template>
    <main class="wrap video-hub-trending">
      <header class="video-hub-trending__header">
        <div class="video-hub-trending__intro">
          <LinkTo @route="videos" class="video-hub-trending__back">
            {{i18n "video_hub.trending.back_to_videos"}}
          </LinkTo>
          <p class="video-hub-trending__eyebrow">
            {{i18n "video_hub.trending.eyebrow"}}
          </p>
          <h1>{{i18n "video_hub.trending.title"}}</h1>
          <p>{{i18n "video_hub.trending.description"}}</p>
          <div class="video-hub-trending__window">
            <span aria-hidden="true"></span>
            {{i18n "video_hub.trending.window"}}
          </div>
        </div>
      </header>

      {{#if this.videos.length}}
        <section
          class="video-hub-trending__feed"
          aria-label={{i18n "video_hub.trending.title"}}
          aria-live="polite"
        >
          {{#each this.videos as |video|}}
            <VideoHubCard @video={{video}} />
          {{/each}}
        </section>
      {{else}}
        <section class="video-hub-trending__empty" aria-live="polite">
          <div class="video-hub-trending__empty-mark" aria-hidden="true">
            <span></span>
            <span></span>
            <span></span>
          </div>
          <h2>{{i18n "video_hub.trending.empty_title"}}</h2>
          <p>{{i18n "video_hub.trending.empty_description"}}</p>
        </section>
      {{/if}}

      {{#if this.showLoadMore}}
        <div class="video-hub-trending__pagination">
          <DButton
            @action={{this.loadMore}}
            @disabled={{this.loadingMore}}
            @isLoading={{this.loadingMore}}
            @label="video_hub.load_more"
            class="btn-default"
          />
        </div>
      {{/if}}
    </main>
  </template>
}
