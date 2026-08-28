import Component from "@glimmer/component";
import { cached, tracked } from "@glimmer/tracking";
import { fn, hash } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import Form from "discourse/components/form";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { i18n } from "discourse-i18n";
import VideoHubLayoutDraggable from "./video-hub-layout-draggable";

export default class VideoHubProfileLayoutEditor extends Component {
  @service router;
  @service toasts;

  @tracked isSaving = false;

  @cached
  get formData() {
    return { sections: this.copySections(this.args.profile.sections ?? []) };
  }

  @action
  registerApi(api) {
    this.formApi = api;
  }

  @action
  onDirtyCheck() {
    return !this.isSaving;
  }

  @action
  async save(data) {
    this.isSaving = true;

    try {
      await ajax(
        `/videos/profile/${encodeURIComponent(this.args.profile.username)}/layout.json`,
        {
          type: "PUT",
          data: {
            layout: {
              sections: this.payloadSections(data.sections ?? []),
            },
          },
        }
      );

      this.toasts.success({
        data: { message: i18n("video_hub.profile.editor.saved") },
        duration: "short",
      });

      await this.router.transitionTo(
        "user.video-hub-profile",
        this.args.profile.username
      );
    } catch (error) {
      popupAjaxError(error);

      try {
        await this.router.refresh();
      } catch (refreshError) {
        popupAjaxError(refreshError);
      }
    } finally {
      this.isSaving = false;
    }
  }

  @action
  moveSectionUp(form, data, sectionIndex) {
    this.moveSectionBy(form, data, sectionIndex, -1);
  }

  @action
  moveSectionDown(form, data, sectionIndex) {
    this.moveSectionBy(form, data, sectionIndex, 1);
  }

  @action
  moveItemUp(form, data, sectionIndex, itemIndex) {
    this.moveItemBy(form, data, sectionIndex, itemIndex, -1);
  }

  @action
  moveItemDown(form, data, sectionIndex, itemIndex) {
    this.moveItemBy(form, data, sectionIndex, itemIndex, 1);
  }

  @action
  dropSection(form, data, targetIndex, { source, position }) {
    const sourceIndex = source.data.index;
    const sections = this.copySections(data.sections ?? []);

    this.moveTo(sections, sourceIndex, targetIndex, position);
    form.set("sections", this.withPositions(sections));
  }

  @action
  dropItem(form, data, targetSectionIndex, targetItemIndex, { source, position }) {
    const sourceSectionIndex = source.data.sectionIndex;
    const sourceItemIndex = source.data.itemIndex;

    if (sourceSectionIndex !== targetSectionIndex) {
      return;
    }

    const sections = this.copySections(data.sections ?? []);
    const items = sections[targetSectionIndex]?.items;

    if (!items) {
      return;
    }

    this.moveTo(items, sourceItemIndex, targetItemIndex, position);
    form.set("sections", this.withPositions(sections));
  }

  moveSectionBy(form, data, sectionIndex, delta) {
    const sections = this.copySections(data.sections ?? []);
    const targetIndex = sectionIndex + delta;

    if (!sections[sectionIndex] || !sections[targetIndex]) {
      return;
    }

    [sections[sectionIndex], sections[targetIndex]] = [
      sections[targetIndex],
      sections[sectionIndex],
    ];

    form.set("sections", this.withPositions(sections));
  }

  moveItemBy(form, data, sectionIndex, itemIndex, delta) {
    const sections = this.copySections(data.sections ?? []);
    const items = sections[sectionIndex]?.items;
    const targetIndex = itemIndex + delta;

    if (!items?.[itemIndex] || !items[targetIndex]) {
      return;
    }

    [items[itemIndex], items[targetIndex]] = [
      items[targetIndex],
      items[itemIndex],
    ];

    form.set("sections", this.withPositions(sections));
  }

  moveTo(records, sourceIndex, targetIndex, position) {
    if (
      sourceIndex === targetIndex ||
      !records[sourceIndex] ||
      !records[targetIndex]
    ) {
      return;
    }

    const [record] = records.splice(sourceIndex, 1);
    let insertIndex = targetIndex;

    if (sourceIndex < targetIndex) {
      insertIndex -= 1;
    }

    if (position === "after") {
      insertIndex += 1;
    }

    insertIndex = Math.max(0, Math.min(insertIndex, records.length));
    records.splice(insertIndex, 0, record);
  }

  withPositions(sections) {
    return sections.map((section, sectionIndex) => ({
      ...section,
      position: sectionIndex,
      items: section.items.map((item, itemIndex) => ({
        ...item,
        position: itemIndex,
      })),
    }));
  }

  payloadSections(sections) {
    return this.withPositions(this.copySections(sections)).map((section) => ({
      id: section.id,
      position: section.position,
      title: section.title === "" ? null : section.title,
      visible: section.visible,
      items: section.items.map((item) => ({
        id: item.id,
        position: item.position,
        pinned: item.pinned,
        visible: item.visible,
      })),
    }));
  }

  copySections(sections) {
    return sections.map((section) => ({
      ...section,
      items: (section.items ?? []).map((item) => ({
        ...item,
        video: item.video ? { ...item.video } : null,
      })),
    }));
  }

  <template>
    <Form
      @data={{this.formData}}
      @onSubmit={{this.save}}
      @onRegisterApi={{this.registerApi}}
      @onDirtyCheck={{this.onDirtyCheck}}
      class="video-hub-profile-editor"
      as |form data|
    >
      {{#if data.sections.length}}
        <form.Collection
          @name="sections"
          as |section sectionIndex sectionData|
        >
          <VideoHubLayoutDraggable
            @type="video-hub-profile-section"
            @data={{hash index=sectionIndex}}
            @onDrop={{fn this.dropSection form data sectionIndex}}
            class="video-hub-profile-editor__section"
            data-section-id={{sectionData.id}}
            data-section-type={{sectionData.section_type}}
          >
            <header class="video-hub-profile-editor__section-heading">
              <div>
                <p class="video-hub-profile-editor__eyebrow">
                  {{sectionData.section_type_label}}
                </p>
                <h2>{{sectionData.display_title}}</h2>
              </div>

              <div class="video-hub-profile-editor__move-actions">
                <form.Button
                  @icon="arrow-up"
                  @label="video_hub.profile.editor.move_up"
                  @action={{fn
                    this.moveSectionUp
                    form
                    data
                    sectionIndex
                  }}
                  class="btn-small video-hub-profile-editor__move-button"
                />
                <form.Button
                  @icon="arrow-down"
                  @label="video_hub.profile.editor.move_down"
                  @action={{fn
                    this.moveSectionDown
                    form
                    data
                    sectionIndex
                  }}
                  class="btn-small video-hub-profile-editor__move-button"
                />
              </div>
            </header>

            <div class="video-hub-profile-editor__section-settings">
              <section.Field
                @name="title"
                @title={{i18n "video_hub.profile.editor.section_title"}}
                @description={{i18n
                  "video_hub.profile.editor.section_title_description"
                }}
                @validation="length:0,100"
                @format="large"
                @type="input"
                as |field|
              >
                <field.Control />
              </section.Field>

              <section.Field
                @name="visible"
                @title={{i18n "video_hub.profile.editor.section_visible"}}
                @description={{i18n
                  "video_hub.profile.editor.section_visible_description"
                }}
                @type="checkbox"
                as |field|
              >
                <field.Control />
              </section.Field>
            </div>

            {{#if sectionData.items.length}}
              <section.Collection
                @name="items"
                as |item itemIndex itemData|
              >
                <VideoHubLayoutDraggable
                  @type="video-hub-profile-item"
                  @data={{hash
                    sectionIndex=sectionIndex
                    itemIndex=itemIndex
                  }}
                  @onDrop={{fn
                    this.dropItem
                    form
                    data
                    sectionIndex
                    itemIndex
                  }}
                  class="video-hub-profile-editor__item"
                  data-item-id={{itemData.id}}
                >
                  <div class="video-hub-profile-editor__item-preview">
                    <div
                      class="video-hub-profile-editor__thumbnail"
                      data-kind={{itemData.video.kind}}
                    >
                      {{#if itemData.video.thumbnail_url}}
                        <img
                          src={{itemData.video.thumbnail_url}}
                          alt=""
                          loading="lazy"
                          decoding="async"
                        />
                      {{else}}
                        <span aria-hidden="true">
                          {{itemData.video.provider_label}}
                        </span>
                      {{/if}}
                    </div>

                    <div class="video-hub-profile-editor__item-copy">
                      <p>{{itemData.video.provider_label}}</p>
                      <strong>{{itemData.video.title}}</strong>
                      {{#if itemData.video.author_name}}
                        <span>{{itemData.video.author_name}}</span>
                      {{/if}}
                    </div>
                  </div>

                  <div class="video-hub-profile-editor__item-controls">
                    <div class="video-hub-profile-editor__move-actions">
                      <form.Button
                        @icon="arrow-up"
                        @label="video_hub.profile.editor.move_up"
                        @action={{fn
                          this.moveItemUp
                          form
                          data
                          sectionIndex
                          itemIndex
                        }}
                        class="btn-small video-hub-profile-editor__item-move-up"
                      />
                      <form.Button
                        @icon="arrow-down"
                        @label="video_hub.profile.editor.move_down"
                        @action={{fn
                          this.moveItemDown
                          form
                          data
                          sectionIndex
                          itemIndex
                        }}
                        class="btn-small video-hub-profile-editor__item-move-down"
                      />
                    </div>

                    <div class="video-hub-profile-editor__item-flags">
                      <item.Field
                        @name="pinned"
                        @title={{i18n "video_hub.profile.editor.item_pinned"}}
                        @type="checkbox"
                        as |field|
                      >
                        <field.Control />
                      </item.Field>

                      <item.Field
                        @name="visible"
                        @title={{i18n "video_hub.profile.editor.item_visible"}}
                        @type="checkbox"
                        as |field|
                      >
                        <field.Control />
                      </item.Field>
                    </div>
                  </div>
                </VideoHubLayoutDraggable>
              </section.Collection>
            {{else}}
              <p class="video-hub-profile-editor__empty-section">
                {{i18n "video_hub.profile.editor.empty_section"}}
              </p>
            {{/if}}
          </VideoHubLayoutDraggable>
        </form.Collection>
      {{else}}
        <form.Alert @type="info" @icon="circle-info">
          {{i18n "video_hub.profile.editor.empty"}}
        </form.Alert>
      {{/if}}

      <form.Actions class="video-hub-profile-editor__actions">
        <form.Submit
          @label="video_hub.profile.editor.save"
          @disabled={{this.isSaving}}
        />
        <form.Reset @label="video_hub.profile.editor.reset" />
      </form.Actions>
    </Form>
  </template>
}
