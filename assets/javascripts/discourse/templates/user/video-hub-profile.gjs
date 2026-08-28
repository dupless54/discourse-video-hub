import VideoHubCard from "../../components/video-hub-card";
import bodyClass from "discourse/helpers/body-class";
import { eq } from "discourse/truth-helpers";
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
              <h2>
                {{#if section.title}}
                  {{section.title}}
                {{else if (eq section.section_type "shorts")}}
                  {{i18n "video_hub.profile.shorts"}}
                {{else}}
                  {{i18n "video_hub.profile.landscape"}}
                {{/if}}
              </h2>
              <span class="video-hub-profile__count">
                {{i18n
                  "video_hub.profile.video_count"
                  count=section.items.length
                }}
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
                    <VideoHubCard @video={{item.video}} />
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
