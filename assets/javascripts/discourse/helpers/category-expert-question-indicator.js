import I18n from "I18n";
import { registerUnbound } from "discourse-common/lib/helpers";
import { htmlSafe } from "@ember/template";

export function categoryExpertQuestionIndicator(topic, currentUser) {
  if (!currentUser || topic.expert_post_group_names) return;

  if (
    currentUser.staff ||
    topic.creator.id === currentUser.id ||
    currentUser.expert_for_category_ids.includes(topic.category_id)
  ) {
    return htmlSafe(
      `<a href="/search?q=is:category_expert_question" class='topic-list-category-expert-question'>${I18n.t(
        "category_experts.topic_list.question"
      )}</a>`
    );
  }
}

registerUnbound(
  "category-expert-question-indicator",
  categoryExpertQuestionIndicator
);
