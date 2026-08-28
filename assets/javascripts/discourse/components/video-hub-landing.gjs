import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { LinkTo } from "@ember/routing";
import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import DButton from "discourse/ui-kit/d-button";
import { i18n } from "discourse-i18n";
import VideoHubCard from "./video-hub-card";
import VideoHubMobileFeedItem from "./video-hub-mobile-feed-item";

export default class VideoHubLanding extends Component {
  @service capabilities;

  @tracked videos = [];
  @tracked pagination = { has_more: false, next_cursor: null };
  @tracked loadingMore = false;
  @tracked activeMobileVideoId = null;

  constructor() {
    super(...arguments);
    this.videos = [...(this.args.model.videos ?? [])];
    this.pagination = this.normalizePagination(this.args.model.pagination);
    this.activeMobileVideoId = this.videos[0]?.id ?? null;
  }

  get providerItems() {
    return this.args.model.providers.map((id) => ({
      id,
      label: i18n(`video_hub.providers.${id}`),
    }));
  }

  get useMobileFeed() {
    return !this.capabilities.viewport.sm;
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
  activateMobileVideo(videoId) {
    if (this.videos.some((video) => video.id === videoId)) {
      this.activeMobileVideoId = videoId;
    }
  }

  @action
  navigateMobileFeed(index) {
    const video = this.videos[index];

    if (!video) {
      return;
    }

    this.activeMobileVideoId = video.id;
    document
      .querySelector(`[data-video-hub-feed-index="${index}"]`)
      ?.scrollIntoView?.({ block: "start" });
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

      if (this.activeMobileVideoId === null) {
        this.activeMobileVideoId = this.videos[0]?.id ?? null;
      }
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
          <div class="video-hub-page__actions">
            <LinkTo
              @route="video-hub-new"
              class="btn btn-primary video-hub-page__publish-link"
            >
              {{i18n "video_hub.publish.cta"}}
            </LinkTo>
          </div>
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
        {{#if this.useMobileFeed}}
          <section
            class="video-hub-mobile-feed"
            aria-label={{i18n "video_hub.feed.label"}}
            aria-describedby="video-hub-mobile-feed-instructions"
          >
            <p id="video-hub-mobile-feed-instructions" class="sr-only">
              {{i18n "video_hub.feed.instructions"}}
            </p>
            {{#each this.videos as |video index|}}
              <VideoHubMobileFeedItem
                @video={{video}}
                @index={{index}}
                @total={{this.videos.length}}
                @activeVideoId={{this.activeMobileVideoId}}
                @onActivate={{this.activateMobileVideo}}
                @onNavigate={{this.navigateMobileFeed}}
              />
            {{/each}}
          </section>
        {{else}}
          <section class="video-hub-page__feed" aria-live="polite">
            {{#each this.videos as |video|}}
              <VideoHubCard @video={{video}} />
            {{/each}}
          </section>
        {{/if}}

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
