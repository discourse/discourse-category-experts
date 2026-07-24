import { registerReviewableTypeLabel } from "discourse/components/reviewable/item";
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
      api.addModelGetter(
        "category",
        "allowingCategoryExpertEndorsements",
        function () {
          return (
            this.custom_fields?.category_expert_group_ids &&
            this.custom_fields?.category_accepting_endorsements
          );
        }
      );

      api.addModelGetter(
        "category",
        "allowingCategoryExpertQuestions",
        function () {
          return (
            this.custom_fields?.category_expert_group_ids &&
            this.custom_fields?.category_accepting_questions
          );
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
