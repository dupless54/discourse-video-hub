import bodyClass from "discourse/helpers/body-class";
import { i18n } from "discourse-i18n";

export default <template>
  {{bodyClass "video-hub-profile-page"}}

  <div class="user-content video-hub-profile" id="user-content">
    <header class="video-hub-profile__header">
      <h1>{{i18n "video_hub.profile.title"}}</h1>
      <p>{{i18n
          "video_hub.profile.description"
          username=@controller.model.profile.username
        }}</p>
    </header>

    {{#if @controller.model.profile.sections.length}}
      <div class="video-hub-profile__sections">
        {{#each @controller.model.profile.sections as |section|}}
          <section
            class="video-hub-profile__section"
            data-section-type={{section.section_type}}
          >
            <header class="video-hub-profile__section-header">
              <h2>{{section.display_title}}</h2>
              <span class="video-hub-profile__count">
                {{section.item_count_label}}
              </span>
            </header>

            {{#if section.items.length}}
              <div
                class="video-hub-profile__grid"
                data-section-type={{section.section_type}}
              >
                {{#each section.items as |item|}}
                  <div
                    class="video-hub-profile__item"
                    data-pinned={{item.pinned}}
                  >
                    {{#if item.pinned}}
                      <span class="video-hub-profile__pin">
                        {{i18n "video_hub.profile.pinned"}}
                      </span>
                    {{/if}}

                    <a
                      class="video-hub-card"
                      data-kind={{item.video.kind}}
                      data-provider={{item.video.provider}}
                      href={{item.video.watch_path}}
                    >
                      <div class="video-hub-card__media">
                        {{#if item.video.thumbnail_url}}
                          <img
                            src={{item.video.thumbnail_url}}
                            alt=""
                            loading="lazy"
                            decoding="async"
                          />
                        {{else}}
                          <div
                            class="video-hub-card__placeholder"
                            aria-hidden="true"
                          >
                            <span>{{item.video.provider_label}}</span>
                          </div>
                        {{/if}}
                      </div>

                      <div class="video-hub-card__body">
                        <p class="video-hub-card__provider">
                          {{item.video.provider_label}}
                        </p>
                        <h2>{{item.video.title}}</h2>

                        {{#if item.video.author_name}}
                          <p class="video-hub-card__author">
                            {{item.video.author_name}}
                          </p>
                        {{/if}}
                      </div>
                    </a>
                  </div>
                {{/each}}
              </div>
            {{else}}
              <p class="video-hub-profile__section-empty">
                {{i18n "video_hub.profile.section_empty"}}
              </p>
            {{/if}}
          </section>
        {{/each}}
      </div>
    {{else}}
      <p class="video-hub-profile__empty">
        {{i18n "video_hub.profile.empty"}}
      </p>
    {{/if}}
  </div>
</template>
