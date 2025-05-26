import Component from "@ember/component";
import { classNames, tagName } from "@ember-decorators/component";
import CategoryExpertsSettings0 from "../../components/category-experts-settings";

@tagName("")
@classNames("category-custom-settings-outlet", "category-experts-settings")
export default class CategoryExpertsSettings extends Component {
  <template><CategoryExpertsSettings0 @category={{this.category}} /></template>
}
