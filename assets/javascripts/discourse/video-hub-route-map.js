export default function () {
  this.route("videos", { path: "/videos" });
  this.route("video-hub-watch", { path: "/videos/:id/:slug" });
}
