import Component from "@glimmer/component";
import { LinkTo } from "@ember/routing";
import { service } from "@ember/service";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

export default class VideoHubProfileNav extends Component {
  @service siteSettings;

  <template>
    {{#if this.siteSettings.video_hub_enabled}}
      {{#unless @outletArgs.model.profile_hidden}}
        <li class="user-main-nav-outlet video-hub-profile-nav">
          <LinkTo @route="user.video-hub-profile">
            {{dIcon "video"}}
            <span>{{i18n "video_hub.profile.nav"}}</span>
          </LinkTo>
        </li>
      {{/unless}}
    {{/if}}
  </template>
}
