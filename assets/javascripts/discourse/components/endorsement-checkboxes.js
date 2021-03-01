import discourseComputed from "discourse-common/utils/decorators";
import Component from "@ember/component";
import { action } from "@ember/object";
import { next } from "@ember/runloop";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";

export default Component.extend({
  user: null,
  categories: null,
  endorsements: null,
  selectedCategoryIds: null,
  startingCategoryIds: null,

  didInsertElement() {
    this._super(...arguments);
    if (!this.endorsements) {
      this.set('endorsements', []);
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

  @discourseComputed("selectedCategoryIds", "startingCategoryIds")
  saveDisabled(categoryIds, startingCategoryIds) {
    if (!categoryIds) {
      return;
    }
    if (categoryIds.length === 0 && startingCategoryIds.length === 0) {
      return true;
    }
    return !categoryIds.filter((c) => !startingCategoryIds.includes(c)).length;
  },

  @action
  save() {
    let categories;
    ajax(`/category-experts/endorse/${this.user.username}.json`, {
      type: "PUT",
      data: {
        categoryIds: this.selectedCategoryIds,
      },
    })
      .then((response) => {
        this.user.set(
          "category_expert_endorsements",
          response.category_expert_endorsements
        );
        this.afterSave();
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
