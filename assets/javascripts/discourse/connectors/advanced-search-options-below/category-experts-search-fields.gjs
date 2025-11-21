import Component, { Input } from "@ember/component";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { classNames, tagName } from "@ember-decorators/component";
import PluginOutlet from "discourse/components/plugin-outlet";
import lazyHash from "discourse/helpers/lazy-hash";
import { i18n } from "discourse-i18n";

@tagName("div")
@classNames(
  "advanced-search-options-below-outlet",
  "category-experts-search-fields"
)
export default class CategoryExpertsSearchFields extends Component {
  static shouldRender(args, context) {
    return context.siteSettings.enable_category_experts;
  }

  init() {
    super.init(...arguments);
    this.set(
      "canSeeIsQuestionFilter",
      this.currentUser &&
        (this.currentUser.staff ||
          (this.currentUser.expert_for_category_ids &&
            this.currentUser.expert_for_category_ids.length))
    );
  }

  @action
  onChangeCheckBox(path, func, event) {
    this.onChangeSearchedTermField(path, func, event.target.checked);
  }

  <template>
    {{#if this.siteSettings.show_category_expert_advanced_search_filters}}
      <div class="control-group">
        <label class="control-label">{{i18n "category_experts.title"}}</label>
        <div class="controls">
          <span>
            <PluginOutlet
              @name="inside-category-experts-search-fields"
              @connectorTagName="div"
              @outletArgs={{lazyHash
                searchedTerms=this.searchedTerms
                onChangeSearchedTermField=this.onChangeSearchedTermField
              }}
            />
          </span>
          <section class="field with-category-expert-response-field">
            <label>
              <Input
                @type="checkbox"
                class="with-category-expert-response"
                @checked={{readonly
                  this.searchedTerms.withCategoryExpertResponse
                }}
                {{on
                  "change"
                  (fn
                    this.onChangeCheckBox
                    "withCategoryExpertResponse"
                    "updateWithCategoryExpertResponse"
                  )
                }}
              />
              {{i18n "category_experts.search.expert_response"}}
            </label>
          </section>
          {{#if this.canSeeIsQuestionFilter}}
            <section class="field is-category-expert-question-field">
              <label>
                <Input
                  @type="checkbox"
                  class="is-category-expert-question"
                  @checked={{readonly
                    this.searchedTerms.isCategoryExpertQuestion
                  }}
                  {{on
                    "change"
                    (fn
                      this.onChangeCheckBox
                      "isCategoryExpertQuestion"
                      "updateIsCategoryExpertQuestion"
                    )
                  }}
                />
                {{i18n "category_experts.search.question"}}
              </label>
            </section>
            <section class="field without-category-expert-post-field">
              <label>
                <Input
                  @type="checkbox"
                  class="without-category-expert-post"
                  @checked={{readonly
                    this.searchedTerms.withoutCategoryExpertPost
                  }}
                  {{on
                    "change"
                    (fn
                      this.onChangeCheckBox
                      "withoutCategoryExpertPost"
                      "updateWithoutCategoryExpertPost"
                    )
                  }}
                />
                {{i18n "category_experts.search.without_post"}}
              </label>
            </section>
          {{/if}}
          {{#if this.currentUser.staff}}
            <section class="field with-unapproved-ce-post-field">
              <label>
                <Input
                  @type="checkbox"
                  class="with-unapproved-post"
                  @checked={{readonly this.searchedTerms.withUnapprovedPost}}
                  {{on
                    "change"
                    (fn
                      this.onChangeCheckBox
                      "withUnapprovedPost"
                      "updateWithUnapprovedPost"
                    )
                  }}
                />
                {{i18n "category_experts.search.unapproved_post"}}
              </label>
            </section>
          {{/if}}
        </div>
      </div>
    {{/if}}
  </template>
}
