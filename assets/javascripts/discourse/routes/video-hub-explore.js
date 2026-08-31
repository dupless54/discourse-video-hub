import Route from "@ember/routing/route";
import { ajax } from "discourse/lib/ajax";

export default class VideoHubExploreRoute extends Route {
  model() {
    return ajax("/videos/feed.json");
  }
}
