import Component from "@ember/component";
import discourseComputed from "discourse-common/utils/decorators";
import { action } from "@ember/object";
import { ajax } from "discourse/lib/ajax";
import { empty } from "@ember/object/computed";

export default Component.extend({
  init() {
    this._super(...arguments);

    ajax("/groups.json").then((response) => {
      const groupOptions = [];
      response.groups.forEach((group) => {
        if (!group.automatic) {
          groupOptions.push({
            name: group.name,
            id: group.id.toString(),
          });
        }
      });
      this.set("groupOptions", groupOptions);
    });
  },

  noGroupSelected: empty("category.custom_fields.category_expert_group_id"),

  @action
  onChangeGroupId(value) {
    this.set("category.custom_fields.category_expert_group_id", value);
  },

  @action
  onChangeAcceptingExpertEndorsements(value) {
    console.log(value)
    this.set("category.custom_fields.category_accepting_endorsements", value ? "true" : null);
  }
});
