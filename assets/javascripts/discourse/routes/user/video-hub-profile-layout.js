import Route from "@ember/routing/route";
import { ajax } from "discourse/lib/ajax";
import { i18n } from "discourse-i18n";

export default class UserVideoHubProfileLayoutRoute extends Route {
  templateName = "user/video-hub-profile-layout";

  async model() {
    const user = this.modelFor("user");
    const [layoutResponse, catalog] = await Promise.all([
      ajax(`/videos/profile/${encodeURIComponent(user.username)}/layout.json`),
      this.fetchCatalog(),
    ]);

    return this.withPresentationLabels(layoutResponse, catalog);
  }

  async fetchCatalog() {
    try {
      return await ajax("/videos.json?limit=20");
    } catch {
      return {
        videos: [],
        pagination: { has_more: false, next_cursor: null },
        failed: true,
      };
    }
  }

  withPresentationLabels(response, catalog) {
    const profile = response?.profile ?? {};

    return {
      ...response,
      profile: {
        ...profile,
        catalog: {
          videos: (catalog?.videos ?? []).map((video) =>
            this.withProviderLabel(video)
          ),
          pagination: catalog?.pagination ?? {
            has_more: false,
            next_cursor: null,
          },
          failed: catalog?.failed === true,
        },
        sections: (profile.sections ?? []).map((section) => ({
          ...section,
          display_title:
            section.title || this.sectionLabel(section.section_type),
          section_type_label: this.sectionLabel(section.section_type),
          items: (section.items ?? []).map((item) => ({
            ...item,
            video: this.withProviderLabel(item.video),
          })),
        })),
      },
    };
  }

  withProviderLabel(video) {
    if (!video) {
      return null;
    }

    return {
      ...video,
      provider_label: this.providerLabel(video.provider),
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
