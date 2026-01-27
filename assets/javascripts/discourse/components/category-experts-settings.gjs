import Component, { Input } from "@ember/component";
import { fn, hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import withEventValue from "discourse/helpers/with-event-value";
import { ajax } from "discourse/lib/ajax";
import { bind } from "discourse/lib/decorators";
import Group from "discourse/models/group";
import { i18n } from "discourse-i18n";
import ComboBox from "select-kit/components/combo-box";
import GroupChooser from "select-kit/components/group-chooser";
import TagChooser from "select-kit/components/tag-chooser";

export default class CategoryExpertsSettings extends Component {
  groupIds = null;
  allGroups = null;

  init() {
    super.init(...arguments);
    this.set(
      "groupIds",
      this.category.custom_fields.category_expert_group_ids
        ? this.category.custom_fields.category_expert_group_ids
            .split("|")
            .map((id) => parseInt(id, 10))
        : []
    );

    Group.findAll().then((groups) => {
      if (this.isDestroying || this.isDestroyed) {
        return;
      }

      this.set(
        "allGroups",
        groups.filter((group) => !group.automatic)
      );
    });

    if (this.siteSettings.enable_badges) {
      ajax("/badges.json").then((response) => {
        if (this.isDestroying || this.isDestroyed) {
          return;
        }

        const badgeOptions = [];
        response.badges.forEach((badge) => {
          if (badge.enabled) {
            const tempBadge = Object.assign({}, badge);
            tempBadge.id = tempBadge.id.toString();
            badgeOptions.push(tempBadge);
          }
        });

        this.set("badgeOptions", badgeOptions);
      });
    }
  }

  @action
  onChangeGroupIds(value) {
    this.set("groupIds", value);
    this.set(
      "category.custom_fields.category_expert_group_ids",
      value.join("|")
    );
  }

  @action
  onChangeAcceptingExpertEndorsements(value) {
    this.set(
      "category.custom_fields.category_accepting_endorsements",
      value ? "true" : null
    );
  }

  @action
  onChangeAcceptingExpertQuestions(value) {
    this.set(
      "category.custom_fields.category_accepting_questions",
      value ? "true" : null
    );
  }

  @bind
  onChangeAutoTag(tags) {
    // TODO(https://github.com/discourse/discourse/pull/36678): The string check can be
    // removed using .discourse-compatibility once the PR is merged.
    const tagName = tags?.[0];
    this.set(
      "category.custom_fields.category_expert_auto_tag",
      tagName?.name ?? tagName ?? null
    );
  }

  <template>
    {{#if this.siteSettings.enable_category_experts}}
      <h3>{{i18n "category_experts.title"}}</h3>
      <section class="field">
        <label class="checkbox-label">
          {{i18n "category_experts.group"}}
        </label>
        <div class="controls">
          <GroupChooser
            @content={{this.allGroups}}
            @value={{this.groupIds}}
            @labelProperty="name"
            @onChange={{this.onChangeGroupIds}}
          />
        </div>
      </section>

      {{#if this.siteSettings.tagging_enabled}}
        <section class="field category-experts-auto-tagging">
          <label class="checkbox-label">
            {{i18n "category_experts.auto_tagging.title"}}
          </label>
          <div class="controls">
            <TagChooser
              @tags={{this.category.custom_fields.category_expert_auto_tag}}
              @categoryId={{this.category.id}}
              @options={{hash limit=1}}
              @onChange={{this.onChangeAutoTag}}
            />
          </div>
          <div class="instructions">
            {{i18n "category_experts.auto_tagging.description"}}
          </div>
        </section>
      {{/if}}

      {{#if this.badgeOptions}}
        <section class="field">
          <label class="checkbox-label">
            {{i18n "category_experts.badge"}}
          </label>
          <div class="controls">
            <ComboBox
              @value={{this.category.custom_fields.category_experts_badge_id}}
              @content={{this.badgeOptions}}
              @nameProperty="name"
              @onChange={{fn
                (mut this.category.custom_fields.category_experts_badge_id)
              }}
              @options={{hash none="category_experts.no_badge"}}
            />
          </div>
        </section>
      {{/if}}

      {{#if this.category.custom_fields.category_expert_group_ids}}
        <section class="field">
          <label class="checkbox-label">
            <Input
              @type="checkbox"
              @checked={{readonly
                this.category.custom_fields.category_accepting_endorsements
              }}
              {{on
                "change"
                (withEventValue
                  this.onChangeAcceptingExpertEndorsements "target.checked"
                )
              }}
            />
            {{i18n "category_experts.accepting_endorsements"}}
          </label>
        </section>

        <section class="field">
          <label class="checkbox-label">
            <Input
              @type="checkbox"
              @checked={{readonly
                this.category.custom_fields.category_accepting_questions
              }}
              {{on
                "change"
                (withEventValue
                  this.onChangeAcceptingExpertQuestions "target.checked"
                )
              }}
            />
            {{i18n "category_experts.accepting_questions"}}
          </label>
        </section>
      {{/if}}
    {{/if}}
  </template>
}
