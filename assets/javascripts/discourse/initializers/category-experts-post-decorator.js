import { withPluginApi } from "discourse/lib/plugin-api";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";

function initializeWithApi(api) {
  const requiresApproval = api.container.lookup("site-settings:main")
    .category_experts_posts_require_approval;

  if (requiresApproval) {
    api.includePostAttributes(
      "needs_category_expert_approval",
      "category_expert_approved",
      "can_manage_category_expert_posts"
    );

    api.addPostMenuButton("category expert approved", (attrs, state) => {
      if (!attrs.can_manage_category_expert_posts) return;

      if (attrs.needs_category_expert_approval) {
        return {
          action: "approveCategoryExpertPost",
          icon: "thumbs-up",
          className: "approve",
          title: "category_experts.approve",
          label: "category_experts.approve",
          position: "first",
        };
      } else if (attrs.category_expert_approved) {
        return {
          action: "unapproveCategoryExpertPost",
          icon: "thumbs-down",
          className: "unapprove",
          title: "category_experts.unapprove",
          position: "second-last-hidden",
        };
      }
    });

    function setPostCategoryExpertAttributes(post, opts = { approved: true }) {
      post.setProperties({
        needs_category_expert_approval: !opts.approved,
        category_expert_approved: opts.approved,
      });

      ajax(`/category-experts/${opts.approved ? "approve" : "unapprove"}`, {
        type: "POST",
        data: { post_id: post.id },
      }).catch(popupAjaxError);
    }

    api.attachWidgetAction("post", "approveCategoryExpertPost", function () {
      setPostCategoryExpertAttributes(this.model, { approved: true });
    });

    api.attachWidgetAction("post", "unapproveCategoryExpertPost", function () {
      setPostCategoryExpertAttributes(this.model, { approved: false });
    });
  }

  api.decorateCookedElement(
    (element, decoratorHelper) => {
      const model = decoratorHelper ? decoratorHelper.getModel() : null;
      if (model) {
        console.log(model);
      }
    },
    { id: "discourse-experts" }
  );
}

export default {
  name: "discourse-experts-post-decorator",

  initialize() {
    withPluginApi("0.10.1", (api) => {
      initializeWithApi(api);
    });
  },
};
