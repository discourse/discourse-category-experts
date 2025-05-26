import Component, { Input } from "@ember/component";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { lt } from "@ember/object/computed";
import { later } from "@ember/runloop";
import DButton from "discourse/components/d-button";
import DModal from "discourse/components/d-modal";
import icon from "discourse/helpers/d-icon";
import loadingSpinner from "discourse/helpers/loading-spinner";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import discourseComputed, { bind } from "discourse/lib/decorators";
import { i18n } from "discourse-i18n";

export default class EndorsementCheckboxes extends Component {
  user = null;
  saving = false;
  categories = null;
  endorsements = null;
  selectedCategoryIds = null;
  startingCategoryIds = null;
  showingSuccess = false;
  loading = true;
  remainingEndorsements = null;

  @lt("remainingEndorsements", 1) outOfEndorsements;

  didInsertElement() {
    super.didInsertElement(...arguments);

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
      })
      .catch(popupAjaxError);
  }

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
  }

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
  }

  @action
  checkboxChanged(categoryId) {
    if (this.startingCategoryIds.includes(categoryId)) {
      return;
    }

    if (this.selectedCategoryIds.includes(categoryId)) {
      this.set(
        "selectedCategoryIds",
        this.selectedCategoryIds.filter((id) => id !== categoryId)
      );
    } else {
      this.set(
        "selectedCategoryIds",
        [...this.selectedCategoryIds].concat([categoryId])
      );
    }
  }

  @bind
  isChecked(categoryId) {
    return (
      this.get("selectedCategoryIds")?.includes(categoryId) ||
      this.isDisabled(categoryId)
    );
  }

  @bind
  isDisabled(categoryId) {
    return this.get("endorsements")?.find((e) => e.category_id === categoryId);
  }

  <template>
    <DModal
      @title={{i18n "category_experts.manage_endorsements.title"}}
      @closeModal={{@closeModal}}
      class="endorse-user-modal"
    >
      <:body>
        <h3>{{i18n
            "category_experts.manage_endorsements.subtitle"
            username=this.user.username
          }}</h3>

        {{#if this.loading}}
          {{loadingSpinner size="large"}}
        {{else}}
          {{#if this.showingSuccess}}
            <div class="endorsement-successful">
              {{icon "check"}}
            </div>
          {{else}}
            {{#each this.categories as |category|}}
              <label class="category-experts-endorsement-row">
                <Input
                  @type="checkbox"
                  @checked={{this.isChecked category.id}}
                  {{on "change" (fn this.checkboxChanged category.id)}}
                  disabled={{this.isDisabled category.id}}
                  name="category"
                  class="category-endorsement-checkbox"
                  id="category-endorsement-{{category.id}}"
                />
                {{category.name}}
              </label>
            {{/each}}
          {{/if}}
        {{/if}}
      </:body>
      <:footer>
        {{#unless this.loading}}
          {{#if this.outOfEndorsements}}
            <div class="alert alert-danger out-of-endorsements-alert">
              {{i18n "category_experts.out_of_endorsements"}}
            </div>
          {{else}}
            <DButton
              class="btn-primary category-endorsement-save"
              @action={{action "save"}}
              @disabled={{this.saveDisabled}}
              @label="category_experts.endorse"
            />
            {{#unless this.currentUser.staff}}
              <div class="remaining-endorsements-notice">
                {{i18n
                  "category_experts.remaining_endorsements"
                  count=this.remainingEndorsements
                }}
              </div>
            {{/unless}}
          {{/if}}
        {{/unless}}
      </:footer>
    </DModal>
  </template>
}
