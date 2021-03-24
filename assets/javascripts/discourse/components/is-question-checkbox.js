import Component from "@ember/component";
import discourseComputed from "discourse-common/utils/decorators";

export default Component.extend({
  init() {
    this._super(...arguments);

    if (this.model.topic && this.model.topic.is_category_expert_question) {
      this.set("model.is_category_expert_question", true);
    }
  },

  @discourseComputed("model", "model.category")
  show(model, category) {
    if (!category || !category.allowingCategoryExpertQuestions) return false;

    return model.editingFirstPost || model.creatingTopic
  }
});
