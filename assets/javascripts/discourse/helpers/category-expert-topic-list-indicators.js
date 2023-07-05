import I18n from "I18n";
import { registerUnbound } from "discourse-common/lib/helpers";
import { htmlSafe } from "@ember/template";

export function categoryExpertTopicListIndicators(context) {
  let html = "";
  html += addApprovedPills(context.topic, context.siteSettings);
  html += addNeedsApprovalPill(
    context.topic,
    context.currentUser,
    context.siteSettings
  );
  html += addIsQuestionPill(
    context.topic,
    context.currentUser,
    context.siteSettings
  );

  return htmlSafe(html);
}

const addApprovedPills = (topic, siteSettings) => {
  let html = "";
  siteSettings.first_post_can_be_considered_expert_post && (topic.expert_post_group_names || []).forEach((groupName) => {
    const href = siteSettings.category_experts_topic_list_link_to_posts
      ? `${topic.url}/${topic.first_expert_post_id}`
      : "/search?q=with:category_expert_response";

    html += `<span class='topic-list-category-expert-tags'>
    <a href=${href} class=${groupName}>
    ${I18n.t("category_experts.topic_list.response_by_group", { groupName })}
    </a>
    </span>
    `;
  });

  return html;
};

const addNeedsApprovalPill = (topic, currentUser, siteSettings) => {
  if (
    currentUser &&
    currentUser.staff &&
    topic.needs_category_expert_post_approval
  ) {
    const href = siteSettings.category_experts_topic_list_link_to_posts
      ? `${topic.url}/${topic.needs_category_expert_post_approval}`
      : "/search?q=with:unapproved_ce_posts";
    return `
      <a href=${href} class="topic-list-category-expert-needs-approval">
      ${I18n.t("category_experts.topic_list.needs_approval")}
      </a>
      `;
  } else {
    return "";
  }
};

const addIsQuestionPill = (topic, currentUser, siteSettings) => {
  if (
    topic.is_category_expert_question &&
    currentUser &&
    (currentUser.staff ||
      (topic.creator && topic.creator.id === currentUser.id) ||
      currentUser.expert_for_category_ids.includes(topic.category_id))
  ) {
    const href = siteSettings.category_experts_topic_list_link_to_posts
      ? topic.url
      : "/search?q=is:category_expert_question";

    return `<a href=${href} class='topic-list-category-expert-question'>${I18n.t(
      "category_experts.topic_list.question"
    )}</a>`;
  } else {
    return "";
  }
};

registerUnbound(
  "category-expert-topic-list-indicators",
  categoryExpertTopicListIndicators
);
