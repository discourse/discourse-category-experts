import Category from "discourse/models/category";
import { and } from "@ember/object/computed";

export default {
  name: "extend-for-category-experts",

  before: "inject-discourse-objects",

  initialize() {
    Category.reopen({
      allowingUserEndorsements: and("custom_fields.category_expert_group_id", "custom_fields.accepting_expert_endorsements")
    });
  },
};
