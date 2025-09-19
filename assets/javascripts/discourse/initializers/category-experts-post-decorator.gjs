import { withPluginApi } from "discourse/lib/plugin-api";
import CategoryExpertPostIndicator from "../components/category-expert-post-indicator";
import CategoryExpertsApproveButton from "../components/category-experts-approve-button";
import CategoryExpertsUnapproveButton from "../components/category-experts-unapprove-button";

function initializeWithApi(api) {
  customizePost(api);

  const requiresApproval = api.container.lookup(
    "service:site-settings"
  ).category_experts_posts_require_approval;

  if (requiresApproval) {
    customizePostMenu(api);
  }
}

function customizePost(api) {
  api.addTrackedPostProperties(
    "needs_category_expert_approval",
    "category_expert_approved_group",
    "can_manage_category_expert_posts"
  );

  api.registerValueTransformer(
    "post-article-class",
    ({ value, context: { post } }) => {
      if (post.category_expert_approved_group) {
        value.push("category-expert-post");
        value.push(`category-expert-${post.category_expert_approved_group}`);
      }

      return value;
    }
  );

  api.renderAfterWrapperOutlet(
    "post-meta-data-poster-name",
    CategoryExpertPostIndicator
  );
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
    withPluginApi((api) => {
      initializeWithApi(api);
    });
  },
};
