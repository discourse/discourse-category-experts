import { withPluginApi } from "discourse/lib/plugin-api";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { next } from "@ember/runloop";

function initializeWithApi(api) {
  const requiresApproval = api.container.lookup("site-settings:main")
    .category_experts_posts_require_approval;

  if (requiresApproval) {
    const appEvents = api.container.lookup("service:app-events");

    api.includePostAttributes(
      "needs_category_expert_approval",
      "category_expert_approved",
      "can_manage_category_expert_posts"
    );

    api.addPostMenuButton("category-expert-post-approval", (attrs, state) => {
      if (!attrs.can_manage_category_expert_posts) return;

      if (
        attrs.needs_category_expert_approval &&
        !attrs.category_expert_approved
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
        attrs.category_expert_approved &&
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

    function setPostCategoryExpertAttributes(post, opts = { approved: true }) {
      ajax(`/category-experts/${opts.approved ? "approve" : "unapprove"}`, {
        type: "POST",
        data: { post_id: post.id },
      })
        .then((response) => {
          post.setProperties({
            needs_category_expert_approval: !opts.approved,
            category_expert_approved: opts.approved ? response.group_name : false,
          });

          appEvents.trigger("post-stream:refresh", { id: post.id });
        })
        .catch(popupAjaxError);
    }

    api.attachWidgetAction("post", "approveCategoryExpertPost", function () {
      setPostCategoryExpertAttributes(this.model, { approved: true });
    });

    api.attachWidgetAction("post", "unapproveCategoryExpertPost", function () {
      setPostCategoryExpertAttributes(this.model, { approved: false });
    });
  }

  api.decorateWidget("post:after", (helper) => {
    const post = helper.getModel();
    next(() => {
      const article = document.querySelector(
        `article[data-post-id="${post.id}"]`
      );
      if (!article) return;

      if (post.category_expert_approved) {
        article.classList.add("category-expert-post");
        article.classList.add(
          `category-expert-${post.category_expert_approved}`
        );
      } else if (post.needs_category_expert_approval) {
        article.classList.remove("category-expert-post");
      }
    });
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
