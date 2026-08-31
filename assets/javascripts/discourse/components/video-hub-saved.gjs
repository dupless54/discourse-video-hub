import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { LinkTo } from "@ember/routing";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import DButton from "discourse/ui-kit/d-button";
import { i18n } from "discourse-i18n";
import VideoHubCard from "./video-hub-card";

class VideoHubSavedItem extends Component {
  @tracked removing = false;

  @action
  async remove() {
    if (this.removing) {
      return;
    }

    this.removing = true;

    try {
      const response = await ajax(`/videos/${this.args.video.id}/save`, {
        type: "DELETE",
      });

      if (response?.saved === false && typeof this.args.onRemoved === "function") {
        this.args.onRemoved(this.args.video.id);
      }
    } catch (error) {
      popupAjaxError(error);
    } finally {
      this.removing = false;
    }
  }

  <template>
    <article class="video-hub-saved__item">
      <VideoHubCard @video={{@video}} />
      <DButton
        @action={{this.remove}}
        @disabled={{this.removing}}
        @isLoading={{this.removing}}
        @label="video_hub.saved.remove"
        class="btn-default video-hub-saved__remove"
      />
    </article>
  </template>
}

export default class VideoHubSaved extends Component {
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
  removeVideo(videoId) {
    this.videos = this.videos.filter((video) => video.id !== videoId);

    if (this.videos.length === 0 && this.canLoadMore) {
      void this.loadMore();
    }
  }

  @action
  async loadMore() {
    if (!this.canLoadMore) {
      return;
    }

    const cursor = this.pagination.next_cursor;
    this.loadingMore = true;

    try {
      const response = await ajax("/videos/saved/feed.json", {
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
    <main class="wrap video-hub-saved">
      <header class="video-hub-saved__header">
        <div class="video-hub-saved__intro">
          <LinkTo @route="videos" class="video-hub-saved__back">
            {{i18n "video_hub.saved.back_to_videos"}}
          </LinkTo>
          <p class="video-hub-saved__eyebrow">
            {{i18n "video_hub.saved.eyebrow"}}
          </p>
          <h1>{{i18n "video_hub.saved.title"}}</h1>
          <p>{{i18n "video_hub.saved.description"}}</p>
        </div>
      </header>

      {{#if this.videos.length}}
        <section
          class="video-hub-saved__feed"
          aria-label={{i18n "video_hub.saved.title"}}
          aria-live="polite"
        >
          {{#each this.videos as |video|}}
            <VideoHubSavedItem
              @video={{video}}
              @onRemoved={{this.removeVideo}}
            />
          {{/each}}
        </section>
      {{else}}
        <section class="video-hub-saved__empty" aria-live="polite">
          <div class="video-hub-saved__empty-mark" aria-hidden="true">
            <span></span>
          </div>
          <h2>{{i18n "video_hub.saved.empty_title"}}</h2>
          <p>{{i18n "video_hub.saved.empty_description"}}</p>
        </section>
      {{/if}}

      {{#if this.showLoadMore}}
        <div class="video-hub-saved__pagination">
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
