import Component from "@glimmer/component";
import { i18n } from "discourse-i18n";
import VideoHubCard from "./video-hub-card";

export default class VideoHubLanding extends Component {
  get providerItems() {
    return this.args.model.providers.map((id) => ({
      id,
      label: i18n(`video_hub.providers.${id}`),
    }));
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

      {{#if @model.videos.length}}
        <section class="video-hub-page__feed" aria-live="polite">
          {{#each @model.videos as |video|}}
            <VideoHubCard @video={{video}} />
          {{/each}}
        </section>
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
