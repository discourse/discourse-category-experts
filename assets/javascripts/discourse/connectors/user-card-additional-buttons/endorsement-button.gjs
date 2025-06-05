import Component from "@ember/component";
import { classNames, tagName } from "@ember-decorators/component";
import EndorsementButton0 from "../../components/endorsement-button";

@tagName("li")
@classNames("user-card-additional-buttons-outlet", "endorsement-button")
export default class EndorsementButton extends Component {
  static shouldRender(args) {
    return !!args.user.category_expert_endorsements;
  }

  <template>
    <EndorsementButton0
      @user={{this.user}}
      @close={{this.close}}
      @location="user-card"
    />
  </template>
}
