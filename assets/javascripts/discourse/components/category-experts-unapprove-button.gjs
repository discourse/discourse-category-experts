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

  @service appEvents;

  get showLabel() {
    return this.args.showLabel;
  }

  @action
  unapproveCategoryExpertPost() {
    setPostCategoryExpertAttributes(this.args.post, this.appEvents, {
      approved: false,
    });
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
