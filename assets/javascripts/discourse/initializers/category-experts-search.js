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

      const withCategoryExpertResponse = this.filterBlocks(REGEXP_WITH_CATEGORY_EXPERT_RESPONSE);
      if (withCategoryExpertResponse.length !== 0) {
        this.set("searchedTerms.categoryExpertsTerm", "with-category-expert-response");
      }

      const isCategoryExpertQuestion = this.filterBlocks(REGEXP_IS_CATEGORY_EXPERT_QUESTION);
      if (isCategoryExpertQuestion.length !== 0) {
        this.set("searchedTerms.categoryExpertsTerm", "is-category-expert-question");
      }

      console.log(this.searchedTerms.categoryExpertsTerm)
    },

    _updateWithCategoryExpertResponse() {
      let searchTerm = this.searchTerm || "";
      if (this.searchedTerms.categoryExpertsTerm === "is-category-expert-question") {
        searchTerm += " with:category_expert_response";
        searchTerm = searchTerm.replace("is:category_expert_question", "");
      } else {
        searchTerm = searchTerm.replace("with:category_expert_response", "");
      }
      this._updateSearchTerm(searchTerm);
    },

    _updateIsCategoryExpertQuestion() {
      let searchTerm = this.searchTerm || "";
      if (this.searchedTerms.categoryExpertsTerm === "with-category-expert-response") {
        searchTerm += " is:category_expert_question";
        searchTerm = searchTerm.replace("with:category_expert_response", "");
      } else {
        searchTerm = searchTerm.replace("is:category_expert_question", "");
      }
      this._updateSearchTerm(searchTerm);
    },
  })

  api.registerConnectorClass(
    "advanced-search-options-below",
    "category-experts-search-fields",
    {
      actions: {
        onChangeCheckBox(path, fn, event) {
          this.onChangeSearchedTermField(path, fn, event.target.checked);
        }
      }
    }
  );
}

export default {
  name: "category-experts-search",

  initialize() {
    withPluginApi("0.8.31", initialize);
  }
};
