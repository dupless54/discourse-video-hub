import { ajax } from "discourse/lib/ajax";
import DiscourseRoute from "discourse/routes/discourse";

export default class VideoHubCollectionsRoute extends DiscourseRoute {
  beforeModel(transition) {
    if (!this.currentUser) {
      transition.send("showLogin");
    }
  }

  model() {
    if (!this.currentUser) {
      return { collections: [] };
    }

    return ajax("/videos/collections.json");
  }
}
