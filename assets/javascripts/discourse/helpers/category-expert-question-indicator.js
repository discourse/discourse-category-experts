import I18n from "I18n";
import { registerUnbound } from "discourse-common/lib/helpers";
import { htmlSafe } from "@ember/template";

export function categoryExpertQuestionIndicator(topic, currentUser) {
  if (!currentUser || topic.expert_post_group_names) {
    return;
  }

  if (
    currentUser.staff ||
    (topic.creator && topic.creator.id === currentUser.id) ||
    currentUser.expert_for_category_ids.includes(topic.category_id)
  ) {
  }
}

registerUnbound(
  "category-expert-question-indicator",
  categoryExpertQuestionIndicator
);
