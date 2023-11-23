import { htmlSafe } from "@ember/template";
import I18n from "I18n";

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
      `<a href="/search?q=is:category_expert_question" class='topic-list-category-expert-question'>${I18n.t(
        "category_experts.topic_list.question"
      )}</a>`
    );
  }
}

export default categoryExpertQuestionIndicator;
