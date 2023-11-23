export default {
  shouldRender(args, component) {
    return component.siteSettings.enable_category_experts;
  },

  setupComponent() {
    this.set(
      "canSeeIsQuestionFilter",
      this.currentUser &&
        (this.currentUser.staff ||
          (this.currentUser.expert_for_category_ids &&
            this.currentUser.expert_for_category_ids.length))
    );
  },

  actions: {
    onChangeCheckBox(path, fn, event) {
      this.onChangeSearchedTermField(path, fn, event.target.checked);
    },
  },
};
