import { ajax } from "discourse/lib/ajax";
import DiscourseRoute from "discourse/routes/discourse";

export default class VideoHubFollowingRoute extends DiscourseRoute {
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

    return ajax("/videos/following/feed.json");
  }
}
