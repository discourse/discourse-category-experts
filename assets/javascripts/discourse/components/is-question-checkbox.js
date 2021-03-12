import discourseComputed from "discourse-common/utils/decorators";
import Component from "@ember/component";

export default Component.extend({
  init() {
    this._super(...arguments);
    console.log(this.model);
  },
});
