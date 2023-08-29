import Composer from "discourse/models/composer";
import { and } from "@ember/object/computed";
import { withPluginApi } from "discourse/lib/plugin-api";
import ExpertGroupChooserModal from "../components/modal/expert-group-chooser";

export default {
  name: "extend-for-category-experts",

  before: "inject-discourse-objects",

  initialize() {
    Composer.serializeOnCreate(
      "is_category_expert_question",
      "is_category_expert_question"
    );

    Composer.serializeOnUpdate(
      "is_category_expert_question",
      "is_category_expert_question"
    );

    withPluginApi("0.8.31", (api) => {
      api.modifyClass("model:category", {
        pluginId: "discourse-category-experts",
        allowingCategoryExpertEndorsements: and(
          "custom_fields.category_expert_group_ids",
          "custom_fields.category_accepting_endorsements"
        ),
        allowingCategoryExpertQuestions: and(
          "custom_fields.category_expert_group_ids",
          "custom_fields.category_accepting_questions"
        ),
      });

      api.addPluginReviewableParam(
        "ReviewableCategoryExpertSuggestion",
        "group_id"
      );

      api.registerReviewableActionModal(
        "approve_category_expert",
        ExpertGroupChooserModal
      );
    });
  },
};
