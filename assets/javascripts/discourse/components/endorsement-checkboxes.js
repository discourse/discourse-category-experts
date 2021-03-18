import discourseComputed from "discourse-common/utils/decorators";
import Component from "@ember/component";
import { action } from "@ember/object";
import { next, later } from "@ember/runloop";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";

export default Component.extend({
  user: null,
  saving: false,
  categories: null,
  endorsements: null,
  selectedCategoryIds: null,
  startingCategoryIds: null,
  showingSuccess: false,

  didInsertElement() {
    this._super(...arguments);
    if (!this.endorsements) {
      this.set("endorsements", []);
    }

    this.set(
      "startingCategoryIds",
      this.endorsements.length
        ? this.endorsements.map((e) => e.category_id)
        : []
    );
    this.set("selectedCategoryIds", [...this.startingCategoryIds]);
    this.endorsements.forEach((endorsement) => {
      const checkbox = this.element.querySelector(
        `#category-endorsement-${endorsement.category_id}`
      );
      checkbox.checked = true;
      checkbox.disabled = true;
    });
  },

  @discourseComputed("saving", "selectedCategoryIds", "startingCategoryIds")
  saveDisabled(saving, categoryIds, startingCategoryIds) {
    if (saving || !categoryIds) {
      return;
    }
    if (categoryIds.length === 0 && startingCategoryIds.length === 0) {
      return true;
    }
    return !categoryIds.filter((c) => !startingCategoryIds.includes(c)).length;
  },

  @action
  save() {
    this.set("saving", true);

    let categories;
    ajax(`/category-experts/endorse/${this.user.username}.json`, {
      type: "PUT",
      data: {
        categoryIds: this.selectedCategoryIds,
      },
    })
      .then((response) => {
        this.set(
          "user.category_expert_endorsements",
          response.category_expert_endorsements
        );

        this.set("showingSuccess", true);
        later(() => {
          this.afterSave();
          this.setProperties({
            showingSuccess: false,
            saving: false,
          });
        }, 300);
      })
      .catch(popupAjaxError);
  },

  @action
  checkboxChanged(categoryId) {
    if (this.startingCategoryIds.includes(categoryId)) return;

    let checked;
    if (this.selectedCategoryIds.includes(categoryId)) {
      this.set(
        "selectedCategoryIds",
        this.selectedCategoryIds.filter((id) => id !== categoryId)
      );
      checked = false;
    } else {
      this.set(
        "selectedCategoryIds",
        [...this.selectedCategoryIds].concat([categoryId])
      );
      checked = true;
    }

    next(
      () =>
        (this.element.querySelector(
          `#category-endorsement-${categoryId}`
        ).checked = checked)
    );
  },
});
