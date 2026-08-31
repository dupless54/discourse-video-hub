import { ajax } from "discourse/lib/ajax";
import DiscourseRoute from "discourse/routes/discourse";

export default class VideoHubSavedRoute extends DiscourseRoute {
  beforeModel(transition) {
    if (!this.currentUser) {
      transition.send("showLogin");
    }
  }

  model() {
    if (!this.currentUser) {
      return {
        videos: [],
        pagination: { has_more: false, next_cursor: null },
      };
    }

    return ajax("/videos/saved/feed.json");
  }
}
