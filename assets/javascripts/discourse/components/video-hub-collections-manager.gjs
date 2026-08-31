import Component from "@glimmer/component";
import { cached, tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import Form from "discourse/components/form";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import DButton from "discourse/ui-kit/d-button";
import { i18n } from "discourse-i18n";

class VideoHubCollectionManagerCard extends Component {
  @service dialog;
  @service toasts;

  @tracked isSaving = false;
  @tracked isDeleting = false;
  @tracked removingVideoId = null;

  @cached
  get formData() {
    return {
      title: this.args.collection.title ?? "",
      description: this.args.collection.description ?? "",
      visible: Boolean(this.args.collection.visible),
    };
  }

  get typeLabel() {
    return i18n(
      `video_hub.collection.${this.args.collection.collection_type === "series" ? "series" : "playlist"}`
    );
  }

  get publicPath() {
    return `/videos/collections/${this.args.collection.id}`;
  }

  get itemCount() {
    return this.args.collection.items?.length ?? 0;
  }

  get isBusy() {
    return this.isSaving || this.isDeleting || this.removingVideoId !== null;
  }

  @action
  async save(data) {
    if (this.isBusy) {
      return;
    }

    this.isSaving = true;

    try {
      const response = await ajax(
        `/videos/collections/${this.args.collection.id}.json`,
        {
          type: "PUT",
          data: {
            collection: {
              title: data.title,
              description: data.description,
              visible: Boolean(data.visible),
            },
          },
        }
      );

      if (response?.collection) {
        this.args.onUpdated(response.collection);
      }

      this.toasts.success({
        data: { message: i18n("video_hub.collections.updated") },
        duration: "short",
      });
    } catch (error) {
      popupAjaxError(error);
    } finally {
      this.isSaving = false;
    }
  }

  @action
  confirmDelete() {
    if (this.isBusy) {
      return;
    }

    this.dialog.confirm({
      message: i18n("video_hub.collections.delete_confirm", {
        title: this.args.collection.title,
      }),
      didConfirm: () => this.deleteCollection(),
    });
  }

  async deleteCollection() {
    if (this.isBusy) {
      return;
    }

    this.isDeleting = true;

    try {
      await ajax(`/videos/collections/${this.args.collection.id}.json`, {
        type: "DELETE",
      });
      this.args.onDeleted(this.args.collection.id);
      this.toasts.success({
        data: { message: i18n("video_hub.collections.deleted") },
        duration: "short",
      });
    } catch (error) {
      popupAjaxError(error);
    } finally {
      this.isDeleting = false;
    }
  }

  @action
  async removeVideo(videoId) {
    if (this.isBusy) {
      return;
    }

    this.removingVideoId = videoId;

    try {
      await ajax(
        `/videos/collections/${this.args.collection.id}/videos/${videoId}.json`,
        { type: "DELETE" }
      );
      this.args.onVideoRemoved(this.args.collection.id, videoId);
      this.toasts.success({
        data: { message: i18n("video_hub.collections.video_removed") },
        duration: "short",
      });
    } catch (error) {
      popupAjaxError(error);
    } finally {
      this.removingVideoId = null;
    }
  }

  <template>
    <article
      class="video-hub-collections__collection"
      data-collection-id={{@collection.id}}
    >
      <header class="video-hub-collections__collection-header">
        <div>
          <div class="video-hub-collections__collection-meta">
            <span class="video-hub-collections__type">{{this.typeLabel}}</span>
            <span>
              {{i18n
                "video_hub.collections.video_count"
                count=this.itemCount
              }}
            </span>
          </div>
          <h2>{{@collection.title}}</h2>
        </div>

        {{#if @collection.visible}}
          <a
            class="btn btn-default video-hub-collections__public-link"
            href={{this.publicPath}}
          >
            {{i18n "video_hub.collections.view_public"}}
          </a>
        {{/if}}
      </header>

      <Form @data={{this.formData}} @onSubmit={{this.save}} as |form|>
        <div class="video-hub-collections__edit-grid">
          <form.Field
            @name="title"
            @title={{i18n "video_hub.collections.title_label"}}
            @validation="required"
            @type="input"
            as |field|
          >
            <field.Control maxlength="100" />
          </form.Field>

          <form.Field
            @name="description"
            @title={{i18n "video_hub.collections.description_label"}}
            @type="textarea"
            as |field|
          >
            <field.Control maxlength="500" />
          </form.Field>

          <form.Field
            @name="visible"
            @title={{i18n "video_hub.collections.visible_label"}}
            @description={{i18n "video_hub.collections.visible_description"}}
            @type="toggle"
            as |field|
          >
            <field.Control />
          </form.Field>
        </div>

        <div class="video-hub-collections__form-actions">
          <form.Submit @label="video_hub.collections.save" />
          <DButton
            @action={{this.confirmDelete}}
            @disabled={{this.isBusy}}
            @label="video_hub.collections.delete"
            class="btn-danger"
          />
        </div>
      </Form>

      <section
        class="video-hub-collections__items"
        aria-label={{i18n "video_hub.collections.items_label"}}
      >
        <div class="video-hub-collections__items-heading">
          <h3>{{i18n "video_hub.collections.items_title"}}</h3>
          <p>{{i18n "video_hub.collections.items_description"}}</p>
        </div>

        {{#if @collection.items.length}}
          <ul class="video-hub-collections__item-list">
            {{#each @collection.items as |item|}}
              <li class="video-hub-collections__item" data-video-id={{item.video_id}}>
                {{#if item.video}}
                  <a
                    class="video-hub-collections__item-preview"
                    href={{item.video.watch_path}}
                  >
                    <div class="video-hub-collections__thumbnail" aria-hidden="true">
                      {{#if item.video.thumbnail_url}}
                        <img src={{item.video.thumbnail_url}} alt="" />
                      {{else}}
                        <span>{{item.video.provider}}</span>
                      {{/if}}
                    </div>
                    <div class="video-hub-collections__item-copy">
                      <strong>{{item.video.title}}</strong>
                      {{#if item.video.author_name}}
                        <span>{{item.video.author_name}}</span>
                      {{/if}}
                    </div>
                  </a>
                {{else}}
                  <div class="video-hub-collections__item-preview">
                    <div
                      class="video-hub-collections__thumbnail video-hub-collections__thumbnail--unavailable"
                      aria-hidden="true"
                    >
                      <span>—</span>
                    </div>
                    <div class="video-hub-collections__item-copy">
                      <strong>{{i18n "video_hub.collections.unavailable_video"}}</strong>
                      <span>{{i18n "video_hub.collections.unavailable_video_hint"}}</span>
                    </div>
                  </div>
                {{/if}}

                <DButton
                  @action={{fn this.removeVideo item.video_id}}
                  @disabled={{this.isBusy}}
                  @label="video_hub.collections.remove_video"
                  class="btn-default video-hub-collections__remove-video"
                />
              </li>
            {{/each}}
          </ul>
        {{else}}
          <div class="video-hub-collections__items-empty">
            {{i18n "video_hub.collections.items_empty"}}
          </div>
        {{/if}}
      </section>
    </article>
  </template>
}

export default class VideoHubCollectionsManager extends Component {
  @service toasts;

  @tracked collections = [];
  @tracked createData = {
    collection_type: "playlist",
    title: "",
    description: "",
  };
  @tracked creating = false;

  constructor() {
    super(...arguments);
    this.collections = [...(this.args.model.collections ?? [])];
  }

  @action
  async createCollection(data) {
    if (this.creating) {
      return;
    }

    this.creating = true;

    try {
      const response = await ajax("/videos/collections.json", {
        type: "POST",
        data: {
          collection: {
            collection_type: data.collection_type,
            title: data.title,
            description: data.description,
          },
        },
      });

      if (response?.collection) {
        this.collections = [...this.collections, response.collection];
        this.createData = {
          collection_type: "playlist",
          title: "",
          description: "",
        };
      }

      this.toasts.success({
        data: { message: i18n("video_hub.collections.created") },
        duration: "short",
      });
    } catch (error) {
      popupAjaxError(error);
    } finally {
      this.creating = false;
    }
  }

  @action
  updateCollection(collection) {
    this.collections = this.collections.map((entry) =>
      entry.id === collection.id ? collection : entry
    );
  }

  @action
  deleteCollection(collectionId) {
    this.collections = this.collections.filter(
      (collection) => collection.id !== collectionId
    );
  }

  @action
  removeVideo(collectionId, videoId) {
    this.collections = this.collections.map((collection) => {
      if (collection.id !== collectionId) {
        return collection;
      }

      return {
        ...collection,
        items: (collection.items ?? []).filter(
          (item) => item.video_id !== videoId
        ),
      };
    });
  }

  <template>
    <main class="wrap video-hub-collections">
      <header class="video-hub-collections__hero">
        <div>
          <a class="video-hub-collections__back" href="/videos">
            {{i18n "video_hub.collections.back_to_videos"}}
          </a>
          <p class="video-hub-collections__eyebrow">
            {{i18n "video_hub.collections.eyebrow"}}
          </p>
          <h1>{{i18n "video_hub.collections.title"}}</h1>
          <p>{{i18n "video_hub.collections.description"}}</p>
        </div>
      </header>

      <section class="video-hub-collections__create">
        <div class="video-hub-collections__create-copy">
          <h2>{{i18n "video_hub.collections.create_title"}}</h2>
          <p>{{i18n "video_hub.collections.create_description"}}</p>
        </div>

        <Form @data={{this.createData}} @onSubmit={{this.createCollection}} as |form|>
          <div class="video-hub-collections__create-grid">
            <form.Field
              @name="collection_type"
              @title={{i18n "video_hub.collections.type_label"}}
              @type="select"
              as |field|
            >
              <field.Control as |select|>
                <select.Option @value="playlist">
                  {{i18n "video_hub.collection.playlist"}}
                </select.Option>
                <select.Option @value="series">
                  {{i18n "video_hub.collection.series"}}
                </select.Option>
              </field.Control>
            </form.Field>

            <form.Field
              @name="title"
              @title={{i18n "video_hub.collections.title_label"}}
              @validation="required"
              @type="input"
              as |field|
            >
              <field.Control maxlength="100" />
            </form.Field>

            <form.Field
              @name="description"
              @title={{i18n "video_hub.collections.description_label"}}
              @type="textarea"
              as |field|
            >
              <field.Control maxlength="500" />
            </form.Field>
          </div>

          <form.Submit @label="video_hub.collections.create" />
        </Form>
      </section>

      {{#if this.collections.length}}
        <section class="video-hub-collections__list" aria-live="polite">
          {{#each this.collections as |collection|}}
            <VideoHubCollectionManagerCard
              @collection={{collection}}
              @onUpdated={{this.updateCollection}}
              @onDeleted={{this.deleteCollection}}
              @onVideoRemoved={{this.removeVideo}}
            />
          {{/each}}
        </section>
      {{else}}
        <section class="video-hub-collections__empty" aria-live="polite">
          <h2>{{i18n "video_hub.collections.empty_title"}}</h2>
          <p>{{i18n "video_hub.collections.empty_description"}}</p>
        </section>
      {{/if}}
    </main>
  </template>
}
