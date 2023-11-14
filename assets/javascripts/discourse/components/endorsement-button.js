import Component from "@ember/component";
import { action } from "@ember/object";
import { inject as service } from "@ember/service";
import discourseComputed from "discourse-common/utils/decorators";
import EndorseUserModal from "./modal/endorse-user";

export default Component.extend({
  modal: service(),
  tagName: "",
  disabled: true,
  user: null,
  endorsements: null,
  categoriesAllowingEndorsements: null,

  init() {
    this._super(...arguments);

    if (
      !this.siteSettings.enable_category_experts ||
      !this.currentUser ||
      this.currentUser.id === this.user.id ||
      this.user.suspended
    ) {
      return;
    }

    this.set(
      "categoriesAllowingEndorsements",
      this.site.categories.filter((c) => c.allowingCategoryExpertEndorsements)
    );
    if (this.categoriesAllowingEndorsements.length) {
      this.set("disabled", false);
    }
  },

  @discourseComputed("user.category_expert_endorsements")
  endorsements(categoryExpertEndorsements) {
    let category_ids = this.categoriesAllowingEndorsements.map((c) => c.id);

    let endorsements = categoryExpertEndorsements.filter((endorsement) => {
      return category_ids.includes(endorsement.category_id);
    });
    this.set("endorsementsCount", endorsements.length);
    return endorsements;
  },

  @action
  openEndorsementModal() {
    if (this.close) {
      this.close();
    }

    if (this.location) {
      this.appEvents.trigger("category-experts:endorse-clicked", {
        location: this.location,
        user_id: this.currentUser.id,
        endorsed_user_id: this.user.id,
      });
    }

    this.modal.show(EndorseUserModal, {
      model: {
        user: this.user,
        endorsements: this.endorsements,
        location: this.location,
      },
    });
  },
});
