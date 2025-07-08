import Component from "@glimmer/component";
import { concat } from "@ember/helper";
import concatClass from "discourse/helpers/concat-class";
import icon from "discourse/helpers/d-icon";

export default class CategoryExpertPostIndicator extends Component {
  static shouldRender(args) {
    return args.post.category_expert_approved_group;
  }

  <template>
    <span
      class={{concatClass
        "category-expert-indicator"
        (concat "category-expert-" @post.category_expert_approved_group)
      }}
    >
      {{icon "circle-check"}}
    </span>
  </template>
}
