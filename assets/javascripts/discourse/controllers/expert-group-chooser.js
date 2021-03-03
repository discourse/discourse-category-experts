import Controller from "@ember/controller";
import ModalFunctionality from "discourse/mixins/modal-functionality";
import { action } from "@ember/object";
import { ajax } from "discourse/lib/ajax";
import { empty } from "@ember/object/computed";

export default Controller.extend(ModalFunctionality, {
  groupOptions: null,
  performDisabled: empty("groupId"),

  onShow() {
    const groupIds = this.model.category.custom_fields.category_expert_group_ids.split(
      "|"
    );
    ajax("/groups.json").then((response) => {
      this.set(
        "groupOptions",
        response.groups.filter((g) => groupIds.includes(g.id.toString()))
      );
    });
  },

  @action
  setGroupId(val) {
    this.model.setProperties({
      group_id: val,
    });
    this.send("closeModal");
    this.performConfirmed(this.action);
  },
});
