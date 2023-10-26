import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";

export default async function setPostCategoryExpertAttributes(
  post,
  appEvents,
  opts = { approved: true }
) {
  try {
    const response = await ajax(
      `/category-experts/${opts.approved ? "approve" : "unapprove"}`,
      {
        type: "POST",
        data: { post_id: post.id },
      }
    );

    post.setProperties({
      needs_category_expert_approval: !opts.approved,
      category_expert_approved_group: opts.approved
        ? response.group_name
        : false,
    });
    post.topic.setProperties({
      needs_category_expert_post_approval:
        response.topic_needs_category_expert_approval,
      expert_post_group_names: response.topic_expert_post_group_names,
    });

    appEvents.trigger("post-stream:refresh", { id: post.id });
  } catch (e) {
    popupAjaxError(e);
  }
}
