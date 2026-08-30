import { LinkTo } from "@ember/routing";
import bodyClass from "discourse/helpers/body-class";
import { i18n } from "discourse-i18n";
import VideoHubProfileLayoutEditor from "../../components/video-hub-profile-layout-editor";

export default <template>
  {{bodyClass "video-hub-profile-page video-hub-profile-editor-page"}}

  <div class="user-content video-hub-profile" id="user-content">
    <header class="video-hub-profile__header video-hub-profile__header--editor">
      <div>
        <h1>{{i18n "video_hub.profile.editor.title"}}</h1>
        <p>{{i18n
            "video_hub.profile.editor.description"
            username=@controller.model.profile.username
          }}</p>
      </div>

      <LinkTo
        @route="user.video-hub-profile"
        class="btn btn-default video-hub-profile__manage"
      >
        {{i18n "video_hub.profile.editor.back"}}
      </LinkTo>
    </header>

    <VideoHubProfileLayoutEditor @profile={{@controller.model.profile}} />
  </div>
</template>
