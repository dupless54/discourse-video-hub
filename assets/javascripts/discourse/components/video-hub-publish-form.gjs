import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import Form from "discourse/components/form";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import DiscourseURL from "discourse/lib/url";
import { i18n } from "discourse-i18n";

const WATCH_PATH = /^\/videos\/\d+\/[^/?#]+$/;

export default class VideoHubPublishForm extends Component {
  @tracked responseError = null;

  formData = {
    url: "",
    caption: "",
  };

  @action
  async publish(data) {
    this.responseError = null;

    try {
      const response = await ajax("/videos", {
        type: "POST",
        data: {
          url: data.url,
          caption: data.caption,
        },
      });
      const watchPath = response?.video?.watch_path;

      if (typeof watchPath !== "string" || !WATCH_PATH.test(watchPath)) {
        this.responseError = i18n("video_hub.publish.invalid_response");
        return;
      }

      DiscourseURL.routeTo(watchPath);
    } catch (error) {
      popupAjaxError(error);
    }
  }

  <template>
    <main class="wrap video-hub-publish">
      <a class="video-hub-publish__back" href="/videos">
        {{i18n "video_hub.publish.back_to_videos"}}
      </a>

      <section class="video-hub-publish__panel">
        <header class="video-hub-publish__header">
          <p class="video-hub-publish__eyebrow">
            {{i18n "video_hub.publish.eyebrow"}}
          </p>
          <h1>{{i18n "video_hub.publish.title"}}</h1>
          <p>{{i18n "video_hub.publish.description"}}</p>
        </header>

        <Form @data={{this.formData}} @onSubmit={{this.publish}} as |form|>
          {{#if this.responseError}}
            <div class="alert alert-error" role="alert">
              {{this.responseError}}
            </div>
          {{/if}}

          <form.Field
            @name="url"
            @title={{i18n "video_hub.publish.url_label"}}
            @validation="required"
            @format="large"
            @type="input"
            as |field|
          >
            <field.Control
              @placeholder={{i18n "video_hub.publish.url_placeholder"}}
            />
          </form.Field>

          <form.Field
            @name="caption"
            @title={{i18n "video_hub.publish.caption_label"}}
            @type="textarea"
            as |field|
          >
            <field.Control
              @placeholder={{i18n "video_hub.publish.caption_placeholder"}}
              maxlength="2000"
            />
          </form.Field>

          <p class="video-hub-publish__hint">
            {{i18n "video_hub.publish.supported_hint"}}
          </p>

          <form.Submit @label="video_hub.publish.submit" />
        </Form>
      </section>
    </main>
  </template>
}
