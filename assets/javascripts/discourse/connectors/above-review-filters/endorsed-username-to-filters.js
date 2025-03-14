import Component from "@ember/component";
import { action, set } from "@ember/object";
import { classNames } from "@ember-decorators/component";

@classNames("endorsed-username-to-filters")
export default class EndorsedUsernameToFilters extends Component {
  @action
  updateEndorsedUsername(usernames) {
    set(this, "outletArgs.additionalFilters.endorsed_username", usernames[0]);
  }
}
