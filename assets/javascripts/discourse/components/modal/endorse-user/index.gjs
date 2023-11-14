import EndorsementCheckboxes from "./endorsement-checkboxes";

const EndorseUserModal = <template>
  <EndorsementCheckboxes
    @user={{@model.user}}
    @endorsements={{@model.endorsements}}
    @location={{@model.location}}
    @closeModal={{@closeModal}}
    @afterSave={{@closeModal}}
  />
</template>;

export default EndorseUserModal;
