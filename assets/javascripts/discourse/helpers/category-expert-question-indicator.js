import { htmlSafe } from "@ember/template";
import { i18n } from "discourse-i18n";

export function categoryExpertQuestionIndicator(topic, currentUser) {
  if (!currentUser || topic.expert_post_group_names?.length) {
    return;
  }

  if (
    currentUser.staff ||
    (topic.creator && topic.creator.id === currentUser.id) ||
    currentUser.expert_for_category_ids.includes(topic.category_id)
  ) {
    return htmlSafe(
      `<a href="/search?q=is:category_expert_question" class='topic-list-category-expert-question'>${i18n(
        "category_experts.topic_list.question"
      )}</a>`
    );
  }
}

export default categoryExpertQuestionIndicator;
