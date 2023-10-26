import { withPluginApi } from "discourse/lib/plugin-api";
import PostAdminMenuApproveButton from "discourse/plugins/discourse-category-experts/discourse/components/post-admin-menu-approve-button";

export default {
  name: "category-experts-post-admin-menu",

  initialize() {
    withPluginApi("1.16.0", (api) => {
      api.addPostAdminMenuButton((attrs) => {
        return {
          component: PostAdminMenuApproveButton,
          data: attrs,
        };
      });
    });
  },
};
