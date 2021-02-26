import Component from "@ember/component";
import { action } from "@ember/object";
import showModal from "discourse/lib/show-modal";

export default Component.extend({
  disabled: true,
  user: null,
  endorsements: null,
  categoriesAllowingEndorsements: null,

  init() {
    this._super(...arguments);
    if (!this.siteSettings.enable_category_experts) {
      return;
    }

    this.set(
      "categoriesAllowingEndorsements",
      this.site.categories.filter((c) => c.allowingUserEndorsements)
    );
    if (this.categoriesAllowingEndorsements.length) {
      this._setValidEndorsements();
      this.set("disabled", false);
    }
  },

  @action
  openEndorsementModal() {
    if (this.close) {
      this.close();
    }

    showModal("endorse-user", {
      model: {
        categories: this.categoriesAllowingEndorsements,
        user: this.user,
        endorsements: this.endorsements,
      },
      title: "category_experts.manage_endorsements.title",
    });
  },

  _setValidEndorsements() {
    if (!this.user.user_endorsements) return;

    let category_ids = this.categoriesAllowingEndorsements.map((c) => c.id);

    this.set(
      "endorsements",
      this.user.user_endorsements.filter((endorsement) => {
        return category_ids.includes(endorsement.category_id);
      })
    );
    this.set("endorsementsCount", this.endorsements.length);
  },
});
