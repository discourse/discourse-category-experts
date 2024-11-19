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

  // TODO (glimmer-post-menu): Remove this static method and move the code into the button action after the widget code is removed
  static approveCategoryExpertPost(post, appEvents) {
    setPostCategoryExpertAttributes(post, appEvents, {
      approved: true,
    });
  }

  @service appEvents;

  get showLabel() {
    return this.args.showLabel ?? true;
  }

  @action
  approveCategoryExpertPost() {
    CategoryExpertsApproveButton.approveCategoryExpertPost(
      this.args.post,
      this.appEvents
    );
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
    appEvents.trigger("post-stream:refresh", { id: post.id });
  } catch (error) {
    popupAjaxError(error);
  }
}
