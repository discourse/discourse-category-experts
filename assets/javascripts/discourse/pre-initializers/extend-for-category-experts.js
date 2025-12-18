import { and } from "@ember/object/computed";
import { registerReviewableTypeLabel } from "discourse/components/reviewable-refresh/item";
import { withPluginApi } from "discourse/lib/plugin-api";
import Composer from "discourse/models/composer";
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

    registerReviewableTypeLabel(
      "ReviewableCategoryExpertSuggestion",
      "review.types.reviewable_category_expert_suggestion.title"
    );

    withPluginApi((api) => {
      api.modifyClass(
        "model:category",
        (Superclass) =>
          class extends Superclass {
            @and(
              "custom_fields.category_expert_group_ids",
              "custom_fields.category_accepting_endorsements"
            )
            allowingCategoryExpertEndorsements;

            @and(
              "custom_fields.category_expert_group_ids",
              "custom_fields.category_accepting_questions"
            )
            allowingCategoryExpertQuestions;
          }
      );

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
