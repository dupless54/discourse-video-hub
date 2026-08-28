import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { modifier } from "ember-modifier";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import dDragAndDropSource from "discourse/ui-kit/modifiers/d-drag-and-drop-source";
import dDragAndDropTarget from "discourse/ui-kit/modifiers/d-drag-and-drop-target";

export default class VideoHubLayoutDraggable extends Component {
  @tracked gripElement;

  captureGrip = modifier((element) => {
    this.gripElement = element;

    return () => (this.gripElement = undefined);
  });

  <template>
    <div
      ...attributes
      {{dDragAndDropSource
        type=@type
        data=@data
        dragHandle=this.gripElement
      }}
      {{dDragAndDropTarget
        accepts=@type
        acceptsSelf=false
        axis="vertical"
        onDrop=@onDrop
      }}
    >
      <span
        {{this.captureGrip}}
        class="video-hub-profile-editor__drag-handle"
        aria-hidden="true"
      >
        {{dIcon "grip-vertical"}}
      </span>

      {{yield}}
    </div>
  </template>
}
