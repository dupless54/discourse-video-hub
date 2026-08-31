import { ajax } from "discourse/lib/ajax";
import DiscourseRoute from "discourse/routes/discourse";

export default class VideoHubTrendingRoute extends DiscourseRoute {
  model() {
    return ajax("/videos/trending/feed.json");
  }
}
