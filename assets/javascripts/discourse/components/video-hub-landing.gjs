import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import DButton from "discourse/ui-kit/d-button";
import { i18n } from "discourse-i18n";
import VideoHubCard from "./video-hub-card";

export default class VideoHubLanding extends Component {
  @tracked videos = [];
  @tracked pagination = { has_more: false, next_cursor: null };
  @tracked loadingMore = false;

  constructor() {
    super(...arguments);
    this.videos = [...(this.args.model.videos ?? [])];
    this.pagination = this.normalizePagination(this.args.model.pagination);
  }

  get providerItems() {
    return this.args.model.providers.map((id) => ({
      id,
      label: i18n(`video_hub.providers.${id}`),
    }));
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
      const response = await ajax("/videos/feed.json", {
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
    <main class="wrap video-hub-page">
      <header class="video-hub-page__hero">
        <div class="video-hub-page__intro">
          <p class="video-hub-page__eyebrow">
            {{i18n "video_hub.eyebrow"}}
          </p>
          <h1>{{i18n "video_hub.title"}}</h1>
          <p>{{i18n "video_hub.description"}}</p>
        </div>

        {{#if this.providerItems.length}}
          <aside
            class="video-hub-page__providers"
            aria-label={{i18n "video_hub.supported_providers"}}
          >
            <span>{{i18n "video_hub.supported_providers"}}</span>
            <ul>
              {{#each this.providerItems as |provider|}}
                <li data-provider={{provider.id}}>{{provider.label}}</li>
              {{/each}}
            </ul>
          </aside>
        {{/if}}
      </header>

      {{#if this.videos.length}}
        <section class="video-hub-page__feed" aria-live="polite">
          {{#each this.videos as |video|}}
            <VideoHubCard @video={{video}} />
          {{/each}}
        </section>

        {{#if this.showLoadMore}}
          <div class="video-hub-page__pagination">
            <DButton
              @action={{this.loadMore}}
              @disabled={{this.loadingMore}}
              @isLoading={{this.loadingMore}}
              @label="video_hub.load_more"
              class="btn-default"
            />
          </div>
        {{/if}}
      {{else}}
        <section class="video-hub-page__empty" aria-live="polite">
          <div class="video-hub-page__empty-preview" aria-hidden="true">
            <span></span>
            <span></span>
            <span></span>
          </div>
          <h2>{{i18n "video_hub.empty_title"}}</h2>
          <p>{{i18n "video_hub.empty_description"}}</p>
        </section>
      {{/if}}
    </main>
  </template>
}
