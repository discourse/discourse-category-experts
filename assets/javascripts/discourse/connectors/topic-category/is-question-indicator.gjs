import Component from "@ember/component";
import { classNames, tagName } from "@ember-decorators/component";
import categoryExpertQuestionIndicator from "../../helpers/category-expert-question-indicator";

@tagName("div")
@classNames("topic-category-outlet", "is-question-indicator")
export default class IsQuestionIndicator extends Component {
  <template>
    {{#if this.topic.is_category_expert_question}}
      {{categoryExpertQuestionIndicator this.topic this.currentUser}}
    {{/if}}
  </template>
}
