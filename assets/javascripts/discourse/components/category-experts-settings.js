import Component from "@ember/component";
import { action } from "@ember/object";
import { ajax } from "discourse/lib/ajax";
import Group from "discourse/models/group";

export default Component.extend({
  groupIds: null,
  allGroups: null,

  init() {
    this._super(...arguments);
    this.set(
      "groupIds",
      this.category.custom_fields.category_expert_group_ids
        ? this.category.custom_fields.category_expert_group_ids
            .split("|")
            .map((id) => parseInt(id, 10))
        : []
    );

    Group.findAll().then((groups) => {
      this.set("allGroups", groups.filterBy("automatic", false));
    });

    if (this.siteSettings.enable_badges) {
      ajax("/badges.json").then((response) => {
        const badgeOptions = [];
        response.badges.forEach((badge) => {
          if (badge.enabled) {
            const tempBadge = Object.assign({}, badge);
            tempBadge.id = tempBadge.id.toString();
            badgeOptions.push(tempBadge);
          }
        });

        this.set("badgeOptions", badgeOptions);
      });
    }
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

  @action
  onChangeAcceptingExpertQuestions(value) {
    this.set(
      "category.custom_fields.category_accepting_questions",
      value ? "true" : null
    );
  },
});
