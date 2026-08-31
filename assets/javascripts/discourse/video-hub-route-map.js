export default function () {
  this.route("videos", { path: "/videos" });
  this.route("video-hub-new", { path: "/videos/new" });
  this.route("video-hub-trending", { path: "/videos/trending" });
  this.route("video-hub-following", { path: "/videos/following" });
  this.route("video-hub-saved", { path: "/videos/saved" });
  this.route("video-hub-collection", { path: "/videos/collections/:id" });
  this.route("video-hub-watch", { path: "/videos/:id/:slug" });
}
