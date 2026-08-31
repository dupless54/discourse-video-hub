import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import DButton from "discourse/ui-kit/d-button";
import { i18n } from "discourse-i18n";

export default class VideoHubCollectionCatalog extends Component {
  @service toasts;

  @tracked isOpen = false;
  @tracked loaded = false;
  @tracked loading = false;
  @tracked loadFailed = false;
  @tracked videos = [];
  @tracked hasMore = false;
  @tracked nextCursor = null;
  @tracked addingVideoId = null;

  get toggleLabel() {
    return this.isOpen
      ? "video_hub.collections.catalog_close"
      : "video_hub.collections.catalog_open";
  }

  get descriptionKey() {
    return this.args.collection.collection_type === "series"
      ? "video_hub.collections.catalog_series_description"
      : "video_hub.collections.catalog_playlist_description";
  }

  get mutationBusy() {
    return this.addingVideoId !== null;
  }

  get controlsDisabled() {
    return Boolean(this.args.disabled) || this.mutationBusy;
  }

  @action
  async toggleCatalog() {
    if (this.controlsDisabled) {
      return;
    }

    this.isOpen = !this.isOpen;

    if (this.isOpen && !this.loaded && !this.loading) {
      await this.loadCatalog(false);
    }
  }

  @action
  async retryCatalog() {
    if (this.loading || this.mutationBusy) {
      return;
    }

    await this.loadCatalog(false);
  }

  @action
  async loadMore() {
    if (this.loading || this.mutationBusy || !this.hasMore || !this.nextCursor) {
      return;
    }

    await this.loadCatalog(true);
  }

  async loadCatalog(append) {
    this.loading = true;
    this.loadFailed = false;

    try {
      const data = { limit: 20 };
      if (append && this.nextCursor) {
        data.cursor = this.nextCursor;
      }

      const response = await ajax(
        `/videos/collections/${this.args.collection.id}/catalog.json`,
        { data }
      );
      const incoming = Array.isArray(response?.videos) ? response.videos : [];

      if (append) {
        const videosById = new Map(this.videos.map((video) => [video.id, video]));
        incoming.forEach((video) => videosById.set(video.id, video));
        this.videos = [...videosById.values()];
      } else {
        this.videos = incoming;
      }

      this.hasMore = Boolean(response?.pagination?.has_more);
      this.nextCursor = response?.pagination?.next_cursor ?? null;
      this.loaded = true;
    } catch (error) {
      this.loadFailed = true;
      popupAjaxError(error);
    } finally {
      this.loading = false;
    }
  }

  @action
  async addVideo(video) {
    if (this.controlsDisabled) {
      return;
    }

    this.addingVideoId = video.id;
    this.args.onBusyChange?.(true);

    try {
      const response = await ajax(
        `/videos/collections/${this.args.collection.id}/videos/${video.id}.json`,
        { type: "PUT" }
      );
      const membership = response?.membership;

      if (membership?.item_id && membership?.video_id) {
        this.args.onVideoAdded?.(this.args.collection.id, {
          id: membership.item_id,
          video_id: membership.video_id,
          position: membership.position,
          video,
        });
        this.videos = this.videos.filter((entry) => entry.id !== video.id);
        this.toasts.success({
          data: { message: i18n("video_hub.collections.video_added") },
          duration: "short",
        });
      }
    } catch (error) {
      popupAjaxError(error);
    } finally {
      this.addingVideoId = null;
      this.args.onBusyChange?.(false);
    }
  }

  <template>
    <section
      class="video-hub-collections__catalog"
      aria-label={{i18n "video_hub.collections.catalog_title"}}
    >
      <header class="video-hub-collections__catalog-header">
        <div class="video-hub-collections__catalog-copy">
          <h3>{{i18n "video_hub.collections.catalog_title"}}</h3>
          <p>{{i18n this.descriptionKey}}</p>
        </div>
        <DButton
          @action={{this.toggleCatalog}}
          @disabled={{this.controlsDisabled}}
          @icon={{if this.isOpen "chevron-up" "plus"}}
          @label={{this.toggleLabel}}
          class="btn-default video-hub-collections__catalog-toggle"
        />
      </header>

      {{#if this.isOpen}}
        <div class="video-hub-collections__catalog-panel" aria-live="polite">
          {{#if this.loadFailed}}
            <div class="video-hub-collections__catalog-state">
              <p>{{i18n "video_hub.collections.catalog_failed"}}</p>
              <DButton
                @action={{this.retryCatalog}}
                @disabled={{this.loading}}
                @label="video_hub.collections.catalog_retry"
                class="btn-default video-hub-collections__catalog-retry"
              />
            </div>
          {{else if this.loading}}
            {{#unless this.loaded}}
              <div class="video-hub-collections__catalog-state">
                {{i18n "video_hub.collections.catalog_loading"}}
              </div>
            {{/unless}}
          {{/if}}

          {{#if this.videos.length}}
            <ul class="video-hub-collections__catalog-list">
              {{#each this.videos as |video|}}
                <li
                  class="video-hub-collections__catalog-card"
                  data-catalog-video-id={{video.id}}
                >
                  <a
                    class="video-hub-collections__catalog-preview"
                    href={{video.watch_path}}
                  >
                    <div
                      class="video-hub-collections__thumbnail"
                      aria-hidden="true"
                    >
                      {{#if video.thumbnail_url}}
                        <img src={{video.thumbnail_url}} alt="" />
                      {{else}}
                        <span>{{video.provider}}</span>
                      {{/if}}
                    </div>
                    <div class="video-hub-collections__item-copy">
                      <strong>{{video.title}}</strong>
                      {{#if video.author_name}}
                        <span>{{video.author_name}}</span>
                      {{/if}}
                    </div>
                  </a>
                  <DButton
                    @action={{fn this.addVideo video}}
                    @disabled={{this.controlsDisabled}}
                    @icon="plus"
                    @label="video_hub.collections.add_video"
                    class="btn-primary video-hub-collections__catalog-add"
                  />
                </li>
              {{/each}}
            </ul>
          {{else if this.loaded}}
            <div class="video-hub-collections__catalog-state">
              {{i18n "video_hub.collections.catalog_empty"}}
            </div>
          {{/if}}

          {{#if this.hasMore}}
            <DButton
              @action={{this.loadMore}}
              @disabled={{this.loading}}
              @label="video_hub.collections.catalog_load_more"
              class="btn-default video-hub-collections__catalog-load-more"
            />
          {{/if}}
        </div>
      {{/if}}
    </section>
  </template>
}
