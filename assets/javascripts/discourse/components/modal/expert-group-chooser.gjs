import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import DModal from "discourse/components/d-modal";
import TapTile from "discourse/components/tap-tile";
import TapTileGrid from "discourse/components/tap-tile-grid";
import { ajax } from "discourse/lib/ajax";
import { i18n } from "discourse-i18n";

export default class ExpertGroupChooserModal extends Component {
  @tracked groupId;
  @tracked groupOptions = null;

  @action
  loadGroups() {
    const expertGroupIds =
      this.args.model.reviewable.category.custom_fields.category_expert_group_ids.split(
        "|"
      );
    ajax("/groups.json").then((response) => {
      this.groupOptions = response.groups.filter((group) =>
        expertGroupIds.includes(group.id.toString())
      );
    });
  }

  @action
  setGroupId(val) {
    this.args.model.reviewable.set("group_id", val);
    this.args.closeModal();
    this.args.model.performConfirmed(this.args.model.action);
  }

  <template>
    <DModal
      @closeModal={{@closeModal}}
      @title={{i18n "review.expert_group_chooser_modal.title"}}
      class="expert-group-chooser-modal"
      {{didInsert this.loadGroups}}
    >
      <TapTileGrid>
        {{#each this.groupOptions as |group|}}
          <TapTile @tileId={{group.id}} @onChange={{action "setGroupId"}}>
            {{group.name}}
          </TapTile>
        {{/each}}
      </TapTileGrid>
    </DModal>
  </template>
}
