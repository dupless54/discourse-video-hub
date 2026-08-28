import Component from "@glimmer/component";
import { i18n } from "discourse-i18n";
import VideoHubPlayer from "./video-hub-player";

export default class VideoHubWatch extends Component {
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

  <template>
    <main class="wrap video-hub-watch">
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
    </main>
  </template>
}
