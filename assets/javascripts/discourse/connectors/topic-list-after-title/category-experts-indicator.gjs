import Component from "@glimmer/component";
import { service } from "@ember/service";
import { i18n } from "discourse-i18n";

export default class extends Component {
  @service siteSettings;
  @service currentUser;

  get approvedPills() {
    const { topic } = this.args.outletArgs;

    return topic.expert_post_group_names?.map((groupName) => ({
      href: this.siteSettings.category_experts_topic_list_link_to_posts
        ? `${topic.url}/${topic.first_expert_post_id}`
        : "/search?q=with:category_expert_response",
      groupName,
    }));
  }

  get needsApprovalHref() {
    const { topic } = this.args.outletArgs;
    if (this.currentUser?.staff && topic.needs_category_expert_post_approval) {
      return this.siteSettings.category_experts_topic_list_link_to_posts
        ? `${topic.url}/${topic.needs_category_expert_post_approval}`
        : "/search?q=with:unapproved_ce_posts";
    }
  }

  get questionPillHref() {
    const { topic } = this.args.outletArgs;
    if (
      topic.is_category_expert_question &&
      this.currentUser &&
      (this.currentUser.staff ||
        (topic.creator && topic.creator.id === this.currentUser.id) ||
        this.currentUser.expert_for_category_ids.includes(topic.category_id))
    ) {
      return this.siteSettings.category_experts_topic_list_link_to_posts
        ? topic.url
        : "/search?q=is:category_expert_question";
    }
  }

  <template>
    {{#each this.approvedPills as |pill|}}
      <span class="topic-list-category-expert-tags">
        <a href={{pill.href}} class={{pill.groupName}}>
          {{i18n
            "category_experts.topic_list.response_by_group"
            groupName=pill.groupName
          }}
        </a>
      </span>
    {{/each}}

    {{#if this.needsApprovalHref}}
      <a
        href={{this.needsApprovalHref}}
        class="topic-list-category-expert-needs-approval"
      >
        {{i18n "category_experts.topic_list.needs_approval"}}
      </a>
    {{/if}}

    {{#if this.questionPillHref}}
      <a
        href={{this.questionPillHref}}
        class="topic-list-category-expert-question"
      >
        {{i18n "category_experts.topic_list.question"}}
      </a>
    {{/if}}
  </template>
}
