import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { cancel } from "@ember/runloop";
import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import discourseLater from "discourse/lib/later";
import DButton from "discourse/ui-kit/d-button";
import { i18n } from "discourse-i18n";
import VideoHubDiscussion from "./video-hub-discussion";
import VideoHubPlayer from "./video-hub-player";

const QUALIFIED_VIEW_DELAY = 3000;

export default class VideoHubWatch extends Component {
  @service currentUser;

  @tracked saved;
  @tracked bookmarkId;
  @tracked saveBusy = false;

  metricMounted = false;
  impressionRequested = false;
  qualifiedRequested = false;
  qualifiedTimer = null;
  saveRequest = null;

  constructor(owner, args) {
    super(owner, args);
    this.saved = Boolean(args.model.video.saved);
    this.bookmarkId = args.model.video.bookmark_id ?? null;
  }

  willDestroy() {
    super.willDestroy();
    this.metricMounted = false;
    this.cancelQualifiedTimer();
    this.saveRequest?.abort?.();
    this.saveRequest = null;
  }

  get video() {
    return this.args.model.video;
  }

  get providerLabel() {
    return i18n(`video_hub.providers.${this.video.provider}`);
  }

  get providerActionLabel() {
    return i18n("video_hub.watch.open_provider", {
      provider: this.providerLabel,
    });
  }

  get saveButtonLabel() {
    return this.saved ? "video_hub.watch.unsave" : "video_hub.watch.save";
  }

  @action
  startMetricTracking() {
    this.metricMounted = true;

    if (!this.currentUser || this.impressionRequested) {
      return;
    }

    this.impressionRequested = true;
    void this.recordImpression();
  }

  @action
  async toggleSaved() {
    if (!this.currentUser || this.saveBusy) {
      return;
    }

    this.saveBusy = true;
    const request = ajax(`/videos/${this.video.id}/save`, {
      type: this.saved ? "DELETE" : "POST",
    });
    this.saveRequest = request;

    try {
      const result = await request;

      if (this.saveRequest !== request) {
        return;
      }

      this.saved = Boolean(result.saved);
      this.bookmarkId = result.bookmark_id ?? null;
    } catch (error) {
      if (this.saveRequest === request && !this.isAbortError(error)) {
        popupAjaxError(error);
      }
    } finally {
      if (this.saveRequest === request) {
        this.saveRequest = null;
        this.saveBusy = false;
      }
    }
  }

  async recordImpression() {
    try {
      await this.sendMetric("impression");
    } catch {
      this.impressionRequested = false;
      return;
    }

    if (this.metricMounted) {
      this.armQualifiedTimer();
    }
  }

  armQualifiedTimer() {
    if (
      this.qualifiedRequested ||
      this.qualifiedTimer !== null ||
      !this.metricMounted
    ) {
      return;
    }

    this.qualifiedTimer = discourseLater(() => {
      this.qualifiedTimer = null;

      if (this.metricMounted) {
        void this.recordQualifiedView();
      }
    }, QUALIFIED_VIEW_DELAY);
  }

  async recordQualifiedView() {
    if (this.qualifiedRequested) {
      return;
    }

    this.qualifiedRequested = true;

    try {
      await this.sendMetric("qualified_view");
    } catch {
      this.qualifiedRequested = false;
    }
  }

  sendMetric(event) {
    return ajax(`/videos/${this.video.id}/metrics`, {
      type: "POST",
      data: { event },
    });
  }

  isAbortError(error) {
    return error?.statusText === "abort" || error?.name === "AbortError";
  }

  cancelQualifiedTimer() {
    if (this.qualifiedTimer !== null) {
      cancel(this.qualifiedTimer);
      this.qualifiedTimer = null;
    }
  }

  <template>
    <main class="wrap video-hub-watch" {{didInsert this.startMetricTracking}}>
      <a class="video-hub-watch__back" href="/videos">
        {{i18n "video_hub.watch.back_to_videos"}}
      </a>

      <article class="video-hub-watch__layout">
        <VideoHubPlayer @video={{this.video}} />

        <section class="video-hub-watch__details">
          <p class="video-hub-watch__provider">{{this.providerLabel}}</p>
          <h1>{{this.video.title}}</h1>

          {{#if this.video.author_name}}
            <p class="video-hub-watch__author">{{this.video.author_name}}</p>
          {{/if}}

          <div class="video-hub-watch__actions">
            <a
              class="btn btn-primary video-hub-watch__provider-link"
              href={{this.video.canonical_url}}
              target="_blank"
              rel="noopener noreferrer nofollow"
              aria-label={{this.providerActionLabel}}
            >
              {{this.providerActionLabel}}
            </a>

            {{#if this.currentUser}}
              <DButton
                @action={{this.toggleSaved}}
                @disabled={{this.saveBusy}}
                @icon="bookmark"
                @label={{this.saveButtonLabel}}
                class="video-hub-watch__save"
              />
            {{/if}}
          </div>
        </section>
      </article>

      <VideoHubDiscussion @topic={{@model.topic}} @video={{this.video}} />
    </main>
  </template>
}
