import Controller from "@ember/controller";
import ModalFunctionality from "discourse/mixins/modal-functionality";

export default Controller.extend(ModalFunctionality, {
  onShow() {
    this.set("afterSave", () => this.send("closeModal")).bind(this)
  }
})
