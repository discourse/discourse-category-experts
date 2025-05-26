import Component from "@ember/component";
import { classNames, tagName } from "@ember-decorators/component";
import EndorsementButton0 from "../../components/endorsement-button";

@tagName("li")
@classNames("user-profile-controls-outlet", "endorsement-button")
export default class EndorsementButton extends Component {
  static shouldRender(args) {
    return !!args.model.category_expert_endorsements;
  }

  <template>
    <EndorsementButton0 @user={{this.model}} @location="user-profile" />
  </template>
}
