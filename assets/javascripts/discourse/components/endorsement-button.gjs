import Component from "@ember/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { tagName } from "@ember-decorators/component";
import DButton from "discourse/components/d-button";
import discourseComputed from "discourse/lib/decorators";
import { i18n } from "discourse-i18n";
import EndorseUserModal from "./modal/endorse-user";

@tagName("")
export default class EndorsementButton extends Component {
  @service modal;

  disabled = true;
  user = null;
  categoriesAllowingEndorsements = null;

  init() {
    super.init(...arguments);

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
  }

  @discourseComputed("user.category_expert_endorsements")
  endorsements(categoryExpertEndorsements) {
    let category_ids = this.categoriesAllowingEndorsements.map((c) => c.id);

    let endorsements = categoryExpertEndorsements.filter((endorsement) => {
      return category_ids.includes(endorsement.category_id);
    });
    this.set("endorsementsCount", endorsements.length);
    return endorsements;
  }

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
  }

  <template>
    {{#unless this.disabled}}
      {{#if this.endorsements}}
        <div class="category-expert-existing-endorsements">
          {{i18n
            "category_experts.existing_endorsements"
            count=this.endorsementsCount
          }}
          <DButton
            @action={{this.openEndorsementModal}}
            class="btn-flat category-expert-endorse-edit"
            @label="btn-default category_experts.edit"
          />
        </div>
      {{else}}
        <DButton
          @action={{this.openEndorsementModal}}
          class="btn-default category-expert-endorse-btn"
          @label="category_experts.endorse"
        />
      {{/if}}
    {{/unless}}
  </template>
}
