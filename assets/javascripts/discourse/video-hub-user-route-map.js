export default {
  resource: "user",
  map() {
    this.route("video-hub-profile", { path: "/videos" });
    this.route("video-hub-profile-layout", { path: "/videos/edit" });
  },
};
