import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import DiscourseRoute from "discourse/routes/discourse";

export default class VideoHubWatchRoute extends DiscourseRoute {
  @service router;

  async model(params) {
    this.requestedPath = `/videos/${params.id}/${params.slug}`;

    const model = await ajax(
      `/videos/${encodeURIComponent(params.id)}/${encodeURIComponent(params.slug)}.json`
    );
    const topicId = model?.video?.topic_id;
    const postId = model?.video?.post_id;

    if (
      !Number.isSafeInteger(topicId) ||
      topicId <= 0 ||
      !Number.isSafeInteger(postId) ||
      postId <= 0
    ) {
      throw new Error("Video Hub watch payload has an invalid topic mapping");
    }

    const topic = await ajax(`/t/${topicId}.json`);
    const rootPost = topic?.post_stream?.posts?.find(
      (post) => post.post_number === 1
    );

    if (topic?.id !== topicId || rootPost?.id !== postId) {
      throw new Error(
        "Video Hub watch payload topic mapping does not match Discourse"
      );
    }

    return { ...model, topic };
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
