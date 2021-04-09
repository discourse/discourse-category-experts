import { withPluginApi } from "discourse/lib/plugin-api";
import { createWidget } from "discourse/widgets/widget";
import { ajax } from "discourse/lib/ajax";

export default {
  name: "category-experts-post-admin-menu",

  initialize() {
    createWidget("category-experts-post-admin-menu-btn", {
      tagName: "ul",
      buildClasses: () => "category-experts-post-admin-menu-btn",
      buildKey: () => "category-experts-post-admin-menu-btn",

      defaultState() {
        return { show: false, loading: false, loaded: false };
      },

      load(attrs, state) {
        return ajax(`/category-experts/retroactive-approval/${attrs.id}.json`)
          .then((response) => {
            state.show = response.can_be_approved;
          })
          .catch(() => {
            state.show = false;
          })
          .finally(() => {
            state.loaded = true;
            this.scheduleRerender();
          });
      },

      html(attrs, state) {
        if (
          attrs.category_expert_approved_group ||
          attrs.needs_category_expert_approval
        ) {
          return;
        }
        if (!state.loaded) {
          this.load(attrs, state);
        } else if (state.show) {
          return this.attach("post-admin-menu-button", {
            action: "approveCategoryExpertPostAdmin",
            title: "category_experts.approve",
            label: "category_experts.approve",
            icon: "thumbs-up",
          });
        }
      },
    });

    withPluginApi("0.8.36", (api) => {
      api.decorateWidget("post-admin-menu:after", (helper) => {
        return helper.attach(
          "category-experts-post-admin-menu-btn",
          helper.attrs
        );
      });
      api.attachWidgetAction("post", "approveCategoryExpertPostAdmin", () => {
        // setPostCategoryExpertAttributes(this.model, { approved: true });
      });
    });
  },
};
