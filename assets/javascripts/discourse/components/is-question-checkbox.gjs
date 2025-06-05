import Component, { Input } from "@ember/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import discourseComputed from "discourse/lib/decorators";
import { i18n } from "discourse-i18n";

export default class IsQuestionCheckbox extends Component {
  @service appEvents;

  init() {
    super.init(...arguments);

    if (
      (this.model.creatingTopic || this.model.editingFirstPost) &&
      this.model.topic &&
      this.model.topic.is_category_expert_question
    ) {
      this.set("model.is_category_expert_question", true);
    }
  }

  @discourseComputed("model", "model.category")
  show(model, category) {
    if (!category || !category.allowingCategoryExpertQuestions) {
      return false;
    }

    return model.editingFirstPost || model.creatingTopic;
  }

  @action
  triggerAppEvent(e) {
    this.appEvents.trigger("category-experts:is-question-checkbox-toggled", {
      checked: e.target.checked,
    });
  }

  <template>
    {{#if this.show}}
      <label class="checkbox-label is-category-expert-question">
        <Input
          @type="checkbox"
          @checked={{this.model.is_category_expert_question}}
          {{on "input" this.triggerAppEvent}}
        />
        {{i18n "category_experts.ask_category_expert"}}
      </label>
    {{/if}}
  </template>
}
