import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { inject as service } from "@ember/service";
import DButton from "discourse/components/d-button";
import { ajax } from "discourse/lib/ajax";
import setPostCategoryExpertAttributes from "discourse/plugins/discourse-category-experts/discourse/lib/set-post-category-expert-attributes";

export default class PostAdminMenuApproveButton extends Component {
  @service appEvents;

  @tracked canBeApproved = false;

  @action
  async approveCategoryExpertPost() {
    await setPostCategoryExpertAttributes(this.args.post, this.appEvents, {
      approved: true,
    });
  }

  @action
  async loadRetroctiveApproval() {
    try {
      const response = await ajax(
        `/category-experts/retroactive-approval/${this.args.post.id}.json`
      );
      this.canBeApproved = response.can_be_approved;
    } catch (error) {
      // eslint-disable-next-line no-console
      console.log(error);
    }
  }

  get shouldRenderButton() {
    return (
      this.canBeApproved &&
      (this.args.post.category_expert_approved_group ||
        this.args.post.needs_category_expert_approval)
    );
  }

  <template>
    {{! would be a great use case for resources }}
    <div {{didInsert this.loadRetroctiveApproval}}></div>

    {{#if this.shouldRenderButton}}
      <DButton
        @label="category_experts.approve"
        @title="category_experts.approve"
        @icon="thumbs-up"
        class="btn btn-transparent category-experts-post-admin-menu-btn"
        @action={{this.approveCategoryExpertPost}}
      />
    {{/if}}
  </template>
}
