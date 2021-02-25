import Component from "@ember/component";
import { action } from "@ember/object";
import { ajax } from "discourse/lib/ajax";

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

  @action
  onChangeGroupId(value) {
    this.set("category.custom_fields.category_expert_group_id", value);
  },
});
