import Component from "@ember/component";
import { classNames, tagName } from "@ember-decorators/component";
import IsQuestionCheckbox from "../../components/is-question-checkbox";

@tagName("")
@classNames(
  "composer-after-save-or-cancel-outlet",
  "composer-is-question-checkbox"
)
export default class ComposerIsQuestionCheckbox extends Component {
  <template>
    {{#unless this.site.mobileView}}
      <IsQuestionCheckbox @model={{this.model}} />
    {{/unless}}
  </template>
}
