import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import { setPostCategoryExpertAttributes } from "./category-experts-approve-button";

export default class CategoryExpertsUnapproveButton extends Component {
  static hidden = true;

  static shouldRender(args) {
    return (
      args.post.category_expert_approved_group &&
      !args.post.needs_category_expert_approval
    );
  }

  // TODO (glimmer-post-menu): Remove this static method and move the code into the button action after the widget code is removed
  static unapproveCategoryExpertPost(post, appEvents) {
    setPostCategoryExpertAttributes(post, appEvents, {
      approved: false,
    });
  }

  @service appEvents;

  get showLabel() {
    return this.args.showLabel;
  }

  @action
  unapproveCategoryExpertPost() {
    CategoryExpertsUnapproveButton.unapproveCategoryExpertPost(
      this.args.post,
      this.appEvents
    );
  }

  <template>
    <DButton
      class="unapprove-category-expert-post"
      ...attributes
      @action={{this.unapproveCategoryExpertPost}}
      @icon="thumbs-down"
      @label={{if this.showLabel "category_experts.unapprove"}}
      @title="category_experts.unapprove"
    />
  </template>
}
