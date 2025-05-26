import Component from "@ember/component";
import { classNames, tagName } from "@ember-decorators/component";
import IsQuestionCheckbox from "../../components/is-question-checkbox";

@tagName("div")
@classNames("composer-fields-outlet", "is-category-expert-question")
export default class IsCategoryExpertQuestion extends Component {
  <template>
    {{#if this.site.mobileView}}
      <IsQuestionCheckbox @model={{this.model}} />
    {{/if}}
  </template>
}
