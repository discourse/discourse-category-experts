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
      # disabled for now, custom field type is not matching correctly
      0
    end
  end
end
