/* eslint-disable ember/no-classic-components, ember/require-tagless-components */
import Component from "@ember/component";
import { hash } from "@ember/helper";
import { action, set } from "@ember/object";
import { classNames } from "@ember-decorators/component";
import EmailGroupUserChooser from "discourse/select-kit/components/email-group-user-chooser";
import { i18n } from "discourse-i18n";

@classNames("endorsed-username-to-filters")
export default class EndorsedUsernameToFilters extends Component {
  @action
  updateEndorsedUsername(usernames) {
    set(this, "outletArgs.additionalFilters.endorsed_username", usernames[0]);
  }

  <template>
    <div
      class="reviewable-filter reviewable-filter-endorsed-username-to-filter"
    >
      <label class="filter-label">{{i18n "review.endorsed_username"}}</label>
      <EmailGroupUserChooser
        @value={{this.outletArgs.additionalFilters.endorsed_username}}
        @onChange={{this.updateEndorsedUsername}}
        @autocomplete="off"
        @options={{hash fullWidthWrap=true maximum=1}}
      />
    </div>
  </template>
}
