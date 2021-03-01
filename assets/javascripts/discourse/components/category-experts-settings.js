import Component from "@ember/component";
import discourseComputed from "discourse-common/utils/decorators";
import { action } from "@ember/object";
import { ajax } from "discourse/lib/ajax";
import { empty } from "@ember/object/computed";

export default Component.extend({
  groupIds: null,

  init() {
    this._super(...arguments);
    this.set(
      "groupIds",
      this.category.custom_fields.category_expert_group_ids
        ? this.category.custom_fields.category_expert_group_ids.split("|")
        : []
    );

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
  onChangeGroupIds(value) {
    this.set("groupIds", value);
    this.set(
      "category.custom_fields.category_expert_group_ids",
      value.join("|")
    );
  },

  @action
  onChangeAcceptingExpertEndorsements(value) {
    this.set(
      "category.custom_fields.category_accepting_endorsements",
      value ? "true" : null
    );
  },
});
