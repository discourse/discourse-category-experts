import Component from "@glimmer/component";
import { service } from "@ember/service";
import CategoryExpertsFormKitSettings from "../../components/category-experts-form-kit-settings";
import CategoryExpertsLegacySettings from "../../components/category-experts-settings";

export default class CategoryExpertsSettings extends Component {
  @service siteSettings;

  <template>
    {{#if this.siteSettings.enable_simplified_category_creation}}
      <CategoryExpertsFormKitSettings
        @category={{@outletArgs.category}}
        @form={{@outletArgs.form}}
        @transientData={{@outletArgs.transientData}}
      />
    {{else}}
      <CategoryExpertsLegacySettings @category={{@outletArgs.category}} />
    {{/if}}
  </template>
}
