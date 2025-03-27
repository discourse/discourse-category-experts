import { next } from "@ember/runloop";
import { withSilencedDeprecations } from "discourse/lib/deprecated";
import { iconNode } from "discourse/lib/icon-library";
import { withPluginApi } from "discourse/lib/plugin-api";
import CategoryExpertsApproveButton from "../components/category-experts-approve-button";
import CategoryExpertsUnapproveButton from "../components/category-experts-unapprove-button";

function initializeWithApi(api) {
  const requiresApproval = api.container.lookup(
    "service:site-settings"
  ).category_experts_posts_require_approval;

  if (requiresApproval) {
    api.includePostAttributes(
      "needs_category_expert_approval",
      "category_expert_approved_group",
      "can_manage_category_expert_posts"
    );

    customizePostMenu(api);
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
        iconNode("circle-check")
      );
    }
  });
}

function customizePostMenu(api) {
  api.registerValueTransformer(
    "post-menu-buttons",
    ({
      value: dag,
      context: {
        post,
        firstButtonKey,
        lastHiddenButtonKey,
        secondLastHiddenButtonKey,
      },
    }) => {
      if (!post.can_manage_category_expert_posts) {
        return;
      }

      dag.add("category-expert-approve-post", CategoryExpertsApproveButton, {
        before: firstButtonKey,
      });

      dag.add(
        "category-expert-unapprove-post",
        CategoryExpertsUnapproveButton,
        {
          before: lastHiddenButtonKey,
          after: secondLastHiddenButtonKey,
        }
      );
    }
  );
}

export default {
  name: "discourse-experts-post-decorator",

  initialize() {
    withPluginApi("1.34.0", (api) => {
      initializeWithApi(api);
    });
  },
};
