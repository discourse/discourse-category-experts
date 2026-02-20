import Component from "@ember/component";
import { LinkTo } from "@ember/routing";
import CountI18n from "discourse/components/count-i18n";
import avatar from "discourse/helpers/avatar";
import categoryLink from "discourse/helpers/category-link";
import { i18n } from "discourse-i18n";

export default class ReviewableCategoryExpertSuggestion extends Component {
  <template>
    <div class="review-item__meta-content">
      <div>
        <div class="row">
          <LinkTo @route="user" @model={{this.reviewable.user.username}}>
            {{avatar this.reviewable.user imageSize="small"}}
            {{this.reviewable.user.username}}
          </LinkTo>
          <CountI18n
            @key="category_experts.review.endorsed_count"
            @count={{this.reviewable.endorsed_count}}
          />
          {{categoryLink this.reviewable.category}}
        </div>

        <div class="row">
          <table class="endorsed-by-table">
            <thead>
              <th>
                <td>{{i18n
                    "category_experts.review.endorsed_by"
                    count=this.reviewable.endorsed_count
                  }}</td>
              </th>
            </thead>
            <tbody>
              {{#each this.reviewable.endorsed_by as |user|}}
                <tr>
                  <td class="endorsed-by">
                    <LinkTo @route="user" @model={{user.username}}>
                      {{avatar user imageSize="tiny"}}
                      {{user.username}}
                    </LinkTo>
                  </td>
                </tr>
              {{/each}}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  </template>
}
