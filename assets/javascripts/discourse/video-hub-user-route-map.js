export default {
  resource: "user",
  map() {
    this.route("video-hub-profile", { path: "/videos" });
  },
};
