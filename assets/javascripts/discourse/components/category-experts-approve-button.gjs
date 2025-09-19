import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";

export default class CategoryExpertsApproveButton extends Component {
  static shouldRender(args) {
    return (
      !args.post.category_expert_approved_group &&
      args.post.needs_category_expert_approval
    );
  }

  @service appEvents;

  get showLabel() {
    return this.args.showLabel ?? true;
  }

  @action
  approveCategoryExpertPost() {
    setPostCategoryExpertAttributes(this.args.post, this.appEvents, {
      approved: true,
    });
  }

  <template>
    <DButton
      class="approve-category-expert-post"
      ...attributes
      @action={{this.approveCategoryExpertPost}}
      @icon="thumbs-up"
      @label={{if this.showLabel "category_experts.approve"}}
      @title="category_experts.approve"
    />
  </template>
}

export async function setPostCategoryExpertAttributes(
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
  } catch (error) {
    popupAjaxError(error);
  }
}
