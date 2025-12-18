/* eslint-disable ember/no-classic-components */
import Component from "@ember/component";
import LegacyCategoryExpertSuggestion from "../reviewable-category-expert-suggestion";

export default class ReviewableLegacyCategoryExpertSuggestion extends Component {
  <template>
    <div class="review-item__meta-content">
      <LegacyCategoryExpertSuggestion @reviewable={{@reviewable}}>
        {{yield}}
      </LegacyCategoryExpertSuggestion>
    </div>
  </template>
}
