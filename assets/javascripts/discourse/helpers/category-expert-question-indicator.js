import I18n from "I18n";
import { registerUnbound } from "discourse-common/lib/helpers";
import { htmlSafe } from "@ember/template";

export function categoryExpertQuestionIndicator(topic, currentUser) {
  if (!currentUser || topic.expert_post_group_names) return;

  if (
    currentUser.staff ||
    topic.user_id === currentUser.id ||
    currentUser.expert_for_category_ids.includes(topic.category_id)
  ) {
    return htmlSafe(
      `<span class='topic-list-category-expert-question'>${I18n.t(
        "category_experts.topic_list.question"
      )}</span>`
    );
  }
}

registerUnbound(
  "category-expert-question-indicator",
  categoryExpertQuestionIndicator
);
