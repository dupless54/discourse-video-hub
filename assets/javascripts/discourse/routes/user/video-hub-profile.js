import Route from "@ember/routing/route";
import { ajax } from "discourse/lib/ajax";

export default class UserVideoHubProfileRoute extends Route {
  model() {
    const user = this.modelFor("user");

    return ajax(`/videos/profile/${encodeURIComponent(user.username)}.json`);
  }
}
