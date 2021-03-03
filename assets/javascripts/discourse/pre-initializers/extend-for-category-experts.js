import Category from "discourse/models/category";
import { and } from "@ember/object/computed";
import { withPluginApi } from "discourse/lib/plugin-api";

export default {
  name: "extend-for-category-experts",

  before: "inject-discourse-objects",

  initialize() {
    Category.reopen({
      allowingCategoryExpertEndorsements: and(
        "custom_fields.category_expert_group_ids",
        "custom_fields.category_accepting_endorsements"
      ),
    });

    withPluginApi("0.8.31", (api) => {
      api.addPluginReviewableParam(
        "ReviewableCategoryExpertSuggestion",
        "group_id"
      );
    });
  },
};
