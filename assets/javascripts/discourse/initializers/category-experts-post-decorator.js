import { next } from "@ember/runloop";
import { withPluginApi } from "discourse/lib/plugin-api";
import { iconNode } from "discourse-common/lib/icon-library";
import setPostCategoryExpertAttributes from "discourse/plugins/discourse-category-experts/discourse/lib/set-post-category-expert-attributes";

function initializeWithApi(api) {
  const requiresApproval = api.container.lookup(
    "service:site-settings"
  ).category_experts_posts_require_approval;

  if (requiresApproval) {
    const appEvents = api.container.lookup("service:app-events");

    api.includePostAttributes(
      "needs_category_expert_approval",
      "category_expert_approved_group",
      "can_manage_category_expert_posts"
    );

    api.addPostMenuButton("category-expert-post-approval", (attrs) => {
      if (!attrs.can_manage_category_expert_posts) {
        return;
      }

      if (
        attrs.needs_category_expert_approval &&
        !attrs.category_expert_approved_group
      ) {
        return {
          action: "approveCategoryExpertPost",
          icon: "thumbs-up",
          className: "approve-category-expert-post",
          title: "category_experts.approve",
          label: "category_experts.approve",
          position: "first",
        };
      } else if (
        attrs.category_expert_approved_group &&
        !attrs.needs_category_expert_approval
      ) {
        return {
          action: "unapproveCategoryExpertPost",
          icon: "thumbs-down",
          className: "unapprove-category-expert-post",
          title: "category_experts.unapprove",
          position: "second-last-hidden",
        };
      }
    });

    api.attachWidgetAction("post", "approveCategoryExpertPost", function () {
      setPostCategoryExpertAttributes(this.model, appEvents, {
        approved: true,
      });
    });

    api.attachWidgetAction("post", "unapproveCategoryExpertPost", function () {
      setPostCategoryExpertAttributes(this.model, appEvents, {
        approved: false,
      });
    });
  }

  api.decorateWidget("post:after", (helper) => {
    const post = helper.getModel();
    next(() => {
      const article = document.querySelector(
        `article[data-post-id="${post.id}"]`
      );
      if (!article) {
        return;
      }

      if (post.category_expert_approved_group) {
        article.classList.add("category-expert-post");
        article.classList.add(
          `category-expert-${post.category_expert_approved_group}`
        );
      } else if (post.needs_category_expert_approval) {
        article.classList.remove("category-expert-post");
      }
    });
  });

  api.decorateWidget("poster-name:after", (helper) => {
    const post = helper.getModel();
    if (post && post.category_expert_approved_group) {
      return helper.h(
        `span.category-expert-indicator.category-expert-${post.category_expert_approved_group}`,
        iconNode("check-circle")
      );
    }
  });
}

export default {
  name: "discourse-experts-post-decorator",

  initialize() {
    withPluginApi("0.10.1", (api) => {
      initializeWithApi(api);
    });
  },
};
