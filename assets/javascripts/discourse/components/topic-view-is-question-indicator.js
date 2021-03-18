import Component from "@ember/component";
import bootbox from "bootbox";
import { action } from "@ember/object";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { readOnly } from "@ember/object/computed";

export default Component.extend({
  canEdit: readOnly("topic.details.can_edit"),
  questionsEnabled: false,

  init() {
    this._super(...arguments);
    this.set(
      "questionsEnabled",
      this.siteSettings.enable_category_experts &&
        this.topic.category &&
        this.topic.category.allowingCategoryExpertQuestions
    );
  },

  @action
  unmarkAsQuestion() {
    bootbox.confirm(
      I18n.t("category_experts.confirm_unmark_as_question"),
      (result) => {
        if (!result) return;

        ajax(`/category-experts/unmark-topic-as-question/${this.topic.id}`, {
          type: "DELETE",
        })
          .then(() => {
            this.topic.set("is_category_expert_question", false);
          })
          .catch(popupAjaxError);
      }
    );
  },

  @action
  markAsQuestion() {
    ajax(`/category-experts/mark-topic-as-question/${this.topic.id}`, {
      type: "POST",
    })
      .then(() => {
        this.topic.set("is_category_expert_question", true);
      })
      .catch(popupAjaxError);
  },
});
