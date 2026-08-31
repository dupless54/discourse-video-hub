import { ajax } from "discourse/lib/ajax";
import DiscourseRoute from "discourse/routes/discourse";

export default class VideoHubCollectionRoute extends DiscourseRoute {
  model(params) {
    return ajax(
      `/videos/collections/${encodeURIComponent(params.id)}.json`
    );
  }

  titleToken() {
    return this.currentModel?.collection?.title || null;
  }
}
