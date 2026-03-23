import Component from "@glimmer/component";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import AsyncContent from "discourse/components/async-content";
import { ajax } from "discourse/lib/ajax";
import { bind } from "discourse/lib/decorators";
import Group from "discourse/models/group";
import ComboBox from "discourse/select-kit/components/combo-box";
import GroupChooser from "discourse/select-kit/components/group-chooser";
import TagChooser from "discourse/select-kit/components/tag-chooser";
import { i18n } from "discourse-i18n";

export default class CategoryExpertsFormKitSettings extends Component {
  @service siteSettings;

  @bind
  async loadData() {
    const groups = await Group.findAll();
    const allGroups = groups.filter((group) => !group.automatic);

    let badgeOptions = null;
    if (this.siteSettings.enable_badges) {
      const response = await ajax("/badges.json");
      badgeOptions = response.badges
        .filter((badge) => badge.enabled)
        .map((badge) => ({ ...badge, id: badge.id.toString() }));
    }

    return { allGroups, badgeOptions };
  }

  get groupIds() {
    const value =
      this.args.transientData?.custom_fields?.category_expert_group_ids;
    if (!value) {
      return [];
    }
    return value.split("|").map((id) => parseInt(id, 10));
  }

  get hasGroupIds() {
    return this.groupIds.length > 0;
  }

  @action
  onChangeGroupIds(value) {
    this.args.form.set(
      "custom_fields.category_expert_group_ids",
      value.join("|")
    );
  }

  @action
  onChangeAutoTag(tags) {
    if (!tags) {
      return;
    }
    const tagName = tags[0];
    this.args.form.set(
      "custom_fields.category_expert_auto_tag",
      tagName?.name ?? tagName ?? null
    );
  }

  @action
  onChangeBadge(value) {
    this.args.form.set("custom_fields.category_experts_badge_id", value);
  }

  <template>
    <AsyncContent @asyncData={{this.loadData}}>
      <:content as |data|>
        <@form.Section
          @title={{i18n "category_experts.title"}}
          class="category-custom-settings-outlet category-experts-settings"
        >
          <@form.Object @name="custom_fields" as |object|>
            <object.Field
              @name="category_expert_group_ids"
              @title={{i18n "category_experts.group"}}
              @format="max"
              @type="custom"
              as |field|
            >
              <field.Control>
                <GroupChooser
                  @content={{data.allGroups}}
                  @value={{this.groupIds}}
                  @labelProperty="name"
                  @onChange={{this.onChangeGroupIds}}
                />
              </field.Control>
            </object.Field>

            {{#if this.siteSettings.tagging_enabled}}
              <object.Field
                @name="category_expert_auto_tag"
                @title={{i18n "category_experts.auto_tagging.title"}}
                @format="max"
                @type="custom"
                as |field|
              >
                <field.Control>
                  <TagChooser
                    @tags={{field.value}}
                    @categoryId={{@category.id}}
                    @options={{hash limit=1}}
                    @onChange={{this.onChangeAutoTag}}
                  />
                </field.Control>
                <field.Meta>
                  {{i18n "category_experts.auto_tagging.description"}}
                </field.Meta>
              </object.Field>
            {{/if}}

            {{#if data.badgeOptions}}
              <object.Field
                @name="category_experts_badge_id"
                @title={{i18n "category_experts.badge"}}
                @format="max"
                @type="custom"
                as |field|
              >
                <field.Control>
                  <ComboBox
                    @value={{field.value}}
                    @content={{data.badgeOptions}}
                    @nameProperty="name"
                    @onChange={{field.set}}
                    @options={{hash none="category_experts.no_badge"}}
                  />
                </field.Control>
              </object.Field>
            {{/if}}

            {{#if this.hasGroupIds}}
              <object.Field
                @name="category_accepting_endorsements"
                @title={{i18n "category_experts.accepting_endorsements"}}
                @format="max"
                @type="checkbox"
                as |field|
              >
                <field.Control />
              </object.Field>

              <object.Field
                @name="category_accepting_questions"
                @title={{i18n "category_experts.accepting_questions"}}
                @format="max"
                @type="checkbox"
                as |field|
              >
                <field.Control />
              </object.Field>
            {{/if}}
          </@form.Object>
        </@form.Section>
      </:content>
    </AsyncContent>
  </template>
}
