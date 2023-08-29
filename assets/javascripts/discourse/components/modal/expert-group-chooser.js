import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { ajax } from "discourse/lib/ajax";

export default class ExpertGroupChooserModal extends Component {
  @tracked groupId;
  @tracked groupOptions = null;

  @action
  loadGroups() {
    const groupIds =
      this.args.model.reviewable.category.custom_fields.category_expert_group_ids.split(
        "|"
      );
    ajax("/groups.json").then((response) => {
      this.groupOptions = response.groups.filter((g) =>
        groupIds.includes(g.id.toString())
      );
    });
  }

  @action
  setGroupId(val) {
    this.args.model.reviewable.set("group_id", val);
    this.args.closeModal();
    this.args.model.performConfirmed(this.action);
  }
}
