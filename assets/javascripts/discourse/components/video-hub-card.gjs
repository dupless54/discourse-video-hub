import Component from "@glimmer/component";
import { i18n } from "discourse-i18n";

export default class VideoHubCard extends Component {
  get providerLabel() {
    return i18n(`video_hub.providers.${this.args.video.provider}`);
  }

  <template>
    <a
      class="video-hub-card"
      data-kind={{@video.kind}}
      data-provider={{@video.provider}}
      href={{@video.watch_path}}
    >
      <div class="video-hub-card__media">
        {{#if @video.thumbnail_url}}
          <img
            src={{@video.thumbnail_url}}
            alt=""
            loading="lazy"
            decoding="async"
          />
        {{else}}
          <div class="video-hub-card__placeholder" aria-hidden="true">
            <span>{{this.providerLabel}}</span>
          </div>
        {{/if}}
      </div>

      <div class="video-hub-card__body">
        <p class="video-hub-card__provider">{{this.providerLabel}}</p>
        <h2>{{@video.title}}</h2>

        {{#if @video.author_name}}
          <p class="video-hub-card__author">{{@video.author_name}}</p>
        {{/if}}
      </div>
    </a>
  </template>
}
