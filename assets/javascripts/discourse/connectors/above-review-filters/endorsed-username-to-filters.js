import { action, set } from "@ember/object";

export default {
  @action
  updateEndorsedUsername(usernames) {
    set(this, "additionalFilters.endorsed_username", usernames[0]);
  },
};
