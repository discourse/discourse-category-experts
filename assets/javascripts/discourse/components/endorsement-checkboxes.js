import discourseComputed from "discourse-common/utils/decorators";
import Component from "@ember/component";
import { action } from "@ember/object";
import { lt } from "@ember/object/computed";
import { later, next } from "@ember/runloop";
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
  loading: true,
  remainingEndorsements: null,
  outOfEndorsements: lt("remainingEndorsements", 1),

  didInsertElement() {
    this._super(...arguments);

    if (!this.endorsements) {
      this.set("endorsements", []);
    }
    this.set(
      "startingCategoryIds",
      this.endorsements.map((e) => e.category_id)
    );

    ajax(`/category-experts/endorsable-categories/${this.user.username}.json`)
      .then((response) => {
        this.setProperties({
          remainingEndorsements: response.extras.remaining_endorsements,
          categories: response.categories,
          selectedCategoryIds: [...this.startingCategoryIds],
          loading: false,
        });
        next(() => {
          this.endorsements.forEach((endorsement) => {
            const checkbox = this.element.querySelector(
              `#category-endorsement-${endorsement.category_id}`
            );
            if (checkbox) {
              checkbox.checked = true;
              checkbox.disabled = true;
            }
          });
        });
      })
      .catch(popupAjaxError);
  },

  @discourseComputed(
    "saving",
    "selectedCategoryIds",
    "startingCategoryIds",
    "remainingEndorsements"
  )
  saveDisabled(
    saving,
    categoryIds,
    startingCategoryIds,
    remainingEndorsements
  ) {
    if (
      remainingEndorsements === 0 ||
      saving ||
      !categoryIds ||
      (categoryIds.length === 0 && startingCategoryIds.length === 0)
    ) {
      return true;
    }
    return !categoryIds.filter((c) => !startingCategoryIds.includes(c)).length;
  },

  @action
  save() {
    if (this.saveDisabled) {
      return;
    }

    this.set("saving", true);

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

        if (this.location) {
          this.appEvents.trigger("category-experts:endorsement-given", {
            location: this.location,
            user_id: this.currentUser.id,
            categoryIds: this.selectedCategoryIds,
            endorsed_user_id: this.user.id,
          });
        }
      })
      .catch(popupAjaxError);
  },

  @action
  checkboxChanged(categoryId) {
    if (this.startingCategoryIds.includes(categoryId)) {
      return;
    }

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
