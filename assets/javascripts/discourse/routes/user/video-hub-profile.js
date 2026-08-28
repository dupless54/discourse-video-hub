import Route from "@ember/routing/route";
import { ajax } from "discourse/lib/ajax";
import { i18n } from "discourse-i18n";

export default class UserVideoHubProfileRoute extends Route {
  templateName = "user/video-hub-profile";

  async model() {
    const user = this.modelFor("user");
    const response = await ajax(
      `/videos/profile/${encodeURIComponent(user.username)}.json`
    );

    return this.withPresentationLabels(response);
  }

  withPresentationLabels(response) {
    const profile = response?.profile ?? {};

    return {
      ...response,
      profile: {
        ...profile,
        sections: (profile.sections ?? []).map((section) => ({
          ...section,
          display_title:
            section.title || this.sectionLabel(section.section_type),
          items: (section.items ?? []).map((item) => ({
            ...item,
            video: {
              ...item.video,
              provider_label: this.providerLabel(item.video?.provider),
            },
          })),
        })),
      },
    };
  }

  sectionLabel(sectionType) {
    return i18n(
      sectionType === "shorts"
        ? "video_hub.profile.shorts"
        : "video_hub.profile.landscape"
    );
  }

  providerLabel(provider) {
    switch (provider) {
      case "youtube":
        return i18n("video_hub.providers.youtube");
      case "tiktok":
        return i18n("video_hub.providers.tiktok");
      case "instagram":
        return i18n("video_hub.providers.instagram");
      default:
        return provider ?? "";
    }
  }
}
