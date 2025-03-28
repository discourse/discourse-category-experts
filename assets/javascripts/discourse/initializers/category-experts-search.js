import { withPluginApi } from "discourse/lib/plugin-api";

function initialize(api) {
  const REGEXP_WITH_CATEGORY_EXPERT_RESPONSE =
    /^with:category_expert_response/gi;
  const REGEXP_IS_CATEGORY_EXPERT_QUESTION = /^is:category_expert_question/gi;
  const REGEXP_WITHOUT_CATEGORY_EXPERT_POST = /^without:category_expert_post/gi;
  const REGEX_WITH_UNAPPROVED_POST = /^with:unapproved_ce_post/gi;

  api.modifyClass(
    "component:search-advanced-options",
    (Superclass) =>
      class extends Superclass {
        init() {
          super.init(...arguments);

          this.set("searchedTerms.withCategoryExpertResponse", null);
        }

        didReceiveAttrs() {
          super.didReceiveAttrs(...arguments);
          [
            {
              regex: REGEXP_WITH_CATEGORY_EXPERT_RESPONSE,
              attr: "searchedTerms.withCategoryExpertResponse",
            },
            {
              regex: REGEXP_IS_CATEGORY_EXPERT_QUESTION,
              attr: "searchedTerms.isCategoryExpertQuestion",
            },
            {
              regex: REGEXP_WITHOUT_CATEGORY_EXPERT_POST,
              attr: "searchedTerms.withoutCategoryExpertPost",
            },
            {
              regex: REGEX_WITH_UNAPPROVED_POST,
              attr: "searchedTerms.withUnapprovedPost",
            },
          ].forEach((search) => {
            if (this.filterBlocks(search.regex).length !== 0) {
              this.set(search.attr, true);
            }
          });
        }

        _updateCategoryExpertTerm(checked, term) {
          let searchTerm = this.searchTerm || "";
          if (checked) {
            searchTerm += ` ${term}`;
          } else {
            searchTerm = searchTerm.replace(term, "");
          }
          this._updateSearchTerm(searchTerm);
        }

        updateWithCategoryExpertResponse() {
          this._updateCategoryExpertTerm(
            this.searchedTerms.withCategoryExpertResponse,
            "with:category_expert_response"
          );
        }

        updateIsCategoryExpertQuestion() {
          this._updateCategoryExpertTerm(
            this.searchedTerms.isCategoryExpertQuestion,
            "is:category_expert_question"
          );
        }

        updateWithoutCategoryExpertPost() {
          this._updateCategoryExpertTerm(
            this.searchedTerms.withoutCategoryExpertPost,
            "without:category_expert_post"
          );
        }

        updateWithUnapprovedPost() {
          this._updateCategoryExpertTerm(
            this.searchedTerms.withUnapprovedPost,
            "with:unapproved_ce_post"
          );
        }
      }
  );
}

export default {
  name: "category-experts-search",

  initialize() {
    withPluginApi("0.8.31", initialize);
  },
};
