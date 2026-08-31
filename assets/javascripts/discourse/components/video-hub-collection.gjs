import Component from "@glimmer/component";
import { LinkTo } from "@ember/routing";
import { i18n } from "discourse-i18n";
import VideoHubCard from "./video-hub-card";

export default class VideoHubCollection extends Component {
  get collection() {
    return this.args.model?.collection ?? {};
  }

  get items() {
    return Array.isArray(this.collection.items) ? this.collection.items : [];
  }

  get owner() {
    return this.collection.owner ?? {};
  }

  get ownerProfilePath() {
    return this.owner.username
      ? `/u/${encodeURIComponent(this.owner.username)}/videos`
      : null;
  }

  get typeLabel() {
    return i18n(
      this.collection.collection_type === "series"
        ? "video_hub.collection.series"
        : "video_hub.collection.playlist"
    );
  }

  get videoCountLabel() {
    return i18n("video_hub.collection.video_count", {
      count: this.items.length,
    });
  }

  <template>
    <main class="wrap video-hub-collection">
      <header class="video-hub-collection__header">
        <div class="video-hub-collection__intro">
          <LinkTo @route="videos" class="video-hub-collection__back">
            {{i18n "video_hub.collection.back_to_videos"}}
          </LinkTo>

          <p class="video-hub-collection__eyebrow">
            {{i18n "video_hub.collection.eyebrow"}}
          </p>
          <h1>{{this.collection.title}}</h1>

          {{#if this.collection.description}}
            <p class="video-hub-collection__description">
              {{this.collection.description}}
            </p>
          {{/if}}

          <div class="video-hub-collection__meta" aria-label={{this.typeLabel}}>
            <span class="video-hub-collection__type">{{this.typeLabel}}</span>
            <span>{{this.videoCountLabel}}</span>
            {{#if this.ownerProfilePath}}
              <a
                class="video-hub-collection__owner"
                href={{this.ownerProfilePath}}
              >
                {{i18n
                  "video_hub.collection.owner"
                  username=this.owner.username
                }}
              </a>
            {{/if}}
          </div>
        </div>
      </header>

      {{#if this.items.length}}
        <section
          class="video-hub-collection__grid"
          aria-label={{this.collection.title}}
        >
          {{#each this.items as |item|}}
            <VideoHubCard @video={{item.video}} />
          {{/each}}
        </section>
      {{else}}
        <section class="video-hub-collection__empty" aria-live="polite">
          <div class="video-hub-collection__empty-mark" aria-hidden="true">
            <span></span>
            <span></span>
            <span></span>
          </div>
          <h2>{{i18n "video_hub.collection.empty_title"}}</h2>
          <p>{{i18n "video_hub.collection.empty_description"}}</p>
        </section>
      {{/if}}
    </main>
  </template>
}
