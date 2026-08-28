import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import DiscourseRoute from "discourse/routes/discourse";

export default class VideoHubWatchRoute extends DiscourseRoute {
  @service router;

  model(params) {
    this.requestedPath = `/videos/${params.id}/${params.slug}`;

    return ajax(
      `/videos/${encodeURIComponent(params.id)}/${encodeURIComponent(params.slug)}.json`
    );
  }

  afterModel(model) {
    const canonicalPath = model?.video?.watch_path;

    if (canonicalPath && canonicalPath !== this.requestedPath) {
      return this.router.replaceWith(canonicalPath);
    }
  }

  titleToken() {
    return this.currentModel?.video?.title || null;
  }
}
