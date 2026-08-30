import Component from "@glimmer/component";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { cancel } from "@ember/runloop";
import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import discourseLater from "discourse/lib/later";
import { i18n } from "discourse-i18n";
import VideoHubDiscussion from "./video-hub-discussion";
import VideoHubPlayer from "./video-hub-player";

const QUALIFIED_VIEW_DELAY = 3000;

export default class VideoHubWatch extends Component {
  @service currentUser;

  metricMounted = false;
  impressionRequested = false;
  qualifiedRequested = false;
  qualifiedTimer = null;

  willDestroy() {
    super.willDestroy();
    this.metricMounted = false;
    this.cancelQualifiedTimer();
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

  @action
  startMetricTracking() {
    this.metricMounted = true;

    if (!this.currentUser || this.impressionRequested) {
      return;
    }

    this.impressionRequested = true;
    void this.recordImpression();
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

  cancelQualifiedTimer() {
    if (this.qualifiedTimer !== null) {
      cancel(this.qualifiedTimer);
      this.qualifiedTimer = null;
    }
  }

  <template>
    <main
      class="wrap video-hub-watch"
      {{didInsert this.startMetricTracking}}
    >
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

          <a
            class="btn btn-primary video-hub-watch__provider-link"
            href={{this.video.canonical_url}}
            target="_blank"
            rel="noopener noreferrer nofollow"
            aria-label={{this.providerActionLabel}}
          >
            {{this.providerActionLabel}}
          </a>
        </section>
      </article>

      <VideoHubDiscussion @topic={{@model.topic}} @video={{this.video}} />
    </main>
  </template>
}
