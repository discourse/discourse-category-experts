import { withPluginApi } from "discourse/lib/plugin-api";

function initialize(api) {
  const REGEXP_WITH_CATEGORY_EXPERT_RESPONSE = /^with:category_expert_response/gi;
  const REGEXP_IS_CATEGORY_EXPERT_QUESTION = /^is:category_expert_question/gi;

  api.modifyClass("component:search-advanced-options", {
    init() {
      this._super(...arguments);

      this.set("searchedTerms.withCategoryExpertResponse", null);
    },

    didReceiveAttrs() {
      this._super(...arguments);
      [
        {
          regex: REGEXP_WITH_CATEGORY_EXPERT_RESPONSE,
          attr: "searchedTerms.withCategoryExpertResponse",
        },
        {
          regex: REGEXP_IS_CATEGORY_EXPERT_QUESTION,
          attr: "searchedTerms.isCategoryExpertQuestion",
        },
      ].forEach((search) => {
        if (this.filterBlocks(search.regex).length !== 0) {
          this.set(search.attr, true);
        }
      });
    },

    _updateCategoryExpertTerm(checked, term) {
      let searchTerm = this.searchTerm || "";
      if (checked) {
        searchTerm += ` ${term}`;
      } else {
        searchTerm = searchTerm.replace(term, "");
      }
      this._updateSearchTerm(searchTerm);
    },

    updateWithCategoryExpertResponse() {
      this._updateCategoryExpertTerm(
        this.searchedTerms.withCategoryExpertResponse,
        "with:category_expert_response"
      );
    },

    updateIsCategoryExpertQuestion() {
      this._updateCategoryExpertTerm(
        this.searchedTerms.isCategoryExpertQuestion,
        "is:category_expert_question"
      );
    },
  });

  api.registerConnectorClass(
    "advanced-search-options-below",
    "category-experts-search-fields",
    {
      actions: {
        onChangeCheckBox(path, fn, event) {
          this.onChangeSearchedTermField(path, fn, event.target.checked);
        },
      },
    }
  );
}

export default {
  name: "category-experts-search",

  initialize() {
    withPluginApi("0.8.31", initialize);
  },
};
