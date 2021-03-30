import Component from "@ember/component";
import { action } from "@ember/object";
import discourseComputed from "discourse-common/utils/decorators";
import showModal from "discourse/lib/show-modal";

export default Component.extend({
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
      this.currentUser.id === this.user.id
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

    let endorsements = this.user.category_expert_endorsements.filter(
      (endorsement) => {
        return category_ids.includes(endorsement.category_id);
      }
    );
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

    showModal("endorse-user", {
      model: {
        categories: this.categoriesAllowingEndorsements,
        user: this.user,
        endorsements: this.endorsements,
        location: this.location
      },
      title: "category_experts.manage_endorsements.title",
    });
  },
});
