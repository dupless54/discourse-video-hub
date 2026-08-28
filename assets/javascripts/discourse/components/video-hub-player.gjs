import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import DButton from "discourse/ui-kit/d-button";
import { i18n } from "discourse-i18n";

const YOUTUBE_ID = /^[A-Za-z0-9_-]{11}$/;
const TIKTOK_ID = /^[0-9]{6,30}$/;

export default class VideoHubPlayer extends Component {
  @tracked active = false;

  get providerLabel() {
    return i18n(`video_hub.providers.${this.args.video.provider}`);
  }

  get embedUrl() {
    const { provider, external_id: externalId } = this.args.video;

    if (
      provider === "youtube" &&
      typeof externalId === "string" &&
      YOUTUBE_ID.test(externalId)
    ) {
      return `https://www.youtube.com/embed/${externalId}?autoplay=1`;
    }

    if (
      provider === "tiktok" &&
      typeof externalId === "string" &&
      TIKTOK_ID.test(externalId)
    ) {
      return `https://www.tiktok.com/player/v1/${externalId}?autoplay=1`;
    }

    return null;
  }

  get showPlayer() {
    return this.active && Boolean(this.embedUrl);
  }

  get playerTitle() {
    return i18n("video_hub.watch.player_title", {
      provider: this.providerLabel,
    });
  }

  @action
  activate() {
    if (this.embedUrl) {
      this.active = true;
    }
  }

  <template>
    <section
      class="video-hub-watch__media"
      data-kind={{@video.kind}}
      data-provider={{@video.provider}}
      aria-label={{i18n "video_hub.watch.preview_label"}}
    >
      {{#if this.showPlayer}}
        <iframe
          class="video-hub-player__iframe"
          src={{this.embedUrl}}
          title={{this.playerTitle}}
          allow="autoplay; encrypted-media; picture-in-picture; fullscreen"
          referrerpolicy="strict-origin-when-cross-origin"
          allowfullscreen
        ></iframe>
      {{else}}
        {{#if @video.thumbnail_url}}
          <img
            src={{@video.thumbnail_url}}
            alt=""
            loading="eager"
            decoding="async"
          />
        {{else}}
          <div class="video-hub-watch__placeholder" aria-hidden="true">
            <span>{{this.providerLabel}}</span>
          </div>
        {{/if}}

        {{#if this.embedUrl}}
          <DButton
            @action={{this.activate}}
            @icon="play"
            @label="video_hub.watch.play_video"
            class="btn-primary video-hub-player__play"
          />
        {{/if}}
      {{/if}}
    </section>
  </template>
}
