# frozen_string_literal: true

module CategoryExperts
  class RemindAdminOfCategoryExpertsPostsJob < ::Jobs::Scheduled
    every 1.week

    def execute(args = {})
      return unless SiteSetting.send_category_experts_reminder_pms

      topic_count = questions_with_unapproved_posts_count
      return if topic_count < 1

      search_url =
        "#{Discourse.base_url}/search?q=#{CGI.escape("is:category_expert_question with:unapproved_ce_post")}"
      creator =
        PostCreator.new(
          Discourse.system_user,
          title: I18n.t("category_experts.admin_reminder.title"),
          raw:
            I18n.t(
              "category_experts.admin_reminder.body",
              { topic_count: topic_count, search_url: search_url },
            ),
          archetype: Archetype.private_message,
          target_group_names: %w[admins moderators],
          subtype: TopicSubtype.system_message,
          skip_validations: true,
        )
      creator.create!
    end

    def questions_with_unapproved_posts_count
      DB.query(<<~SQL).count
            SELECT topics.id
            FROM topics
            INNER JOIN topic_custom_fields tc1 ON topics.id = tc1.topic_id
            INNER JOIN topic_custom_fields tc2 ON topics.id = tc2.topic_id
            WHERE tc1.name = '#{CategoryExperts::TOPIC_IS_CATEGORY_EXPERT_QUESTION}' AND
                  tc1.value = 't' AND
                  tc2.name = '#{CategoryExperts::TOPIC_NEEDS_EXPERT_POST_APPROVAL}' AND
                  tc2.value = 't'
            EXCEPT
            SELECT topics.id
            FROM topics
            INNER JOIN topic_custom_fields tc3 ON topics.id = tc3.topic_id
            WHERE tc3.name = '#{CategoryExperts::TOPIC_EXPERT_POST_GROUP_NAMES}' AND
                  tc3.value <> '' AND
                  tc3.value IS NOT NULL
      SQL
    end
  end
end
