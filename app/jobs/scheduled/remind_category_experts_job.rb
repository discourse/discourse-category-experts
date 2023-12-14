# frozen_string_literal: true

module CategoryExperts
  class RemindCategoryExpertsJob < ::Jobs::Scheduled
    every 1.week

    def execute(args = {})
      return unless SiteSetting.send_category_experts_reminder_pms

      username_raw_map = {}

      category_custom_fields.each do |category_custom_field|
        unanswered_count = unanswered_topic_count_for(category_custom_field.category_id)
        next if unanswered_count < 1

        category = category_custom_field.category
        group_ids = category_custom_field.value.split("|")

        usernames_in_group_ids(group_ids).each do |username|
          search_path =
            "/search?q=#{CGI.escape("##{category.name} is:category_expert_question without:category_expert_post")}"
          raw =
            I18n.t(
              "category_experts.experts_reminder.raw_for_category",
              {
                topic_count: unanswered_count,
                category_name: category.name,
                category_url: category.url,
                search_url: "#{Discourse.base_url}#{search_path}",
              },
            )
          username_raw_map[username] = (username_raw_map[username] || "") + raw
        end
      end

      username_raw_map.each { |username, raw| create_message(username, raw) }
    end

    private

    def category_custom_fields
      CategoryCustomField
        .where(name: CategoryExperts::CATEGORY_EXPERT_GROUP_IDS)
        .where.not(value: nil)
    end

    def usernames_in_group_ids(group_ids)
      User.joins(:group_users).where(group_users: { group_id: group_ids }).pluck(:username).uniq
    end

    def create_message(username, raw)
      creator =
        PostCreator.new(
          Discourse.system_user,
          title: I18n.t("category_experts.experts_reminder.title"),
          raw: raw,
          archetype: Archetype.private_message,
          target_usernames: username,
          subtype: TopicSubtype.system_message,
          skip_validations: true,
        )
      creator.create!
    end

    def unanswered_topic_count_for(category_id)
      DB.query(<<~SQL, category_id: category_id).count
            SELECT topics.id FROM topics
            INNER JOIN topic_custom_fields tc ON topics.id = tc.topic_id
            WHERE topics.category_id = :category_id AND
                  tc.name = '#{CategoryExperts::TOPIC_IS_CATEGORY_EXPERT_QUESTION}' AND
                  tc.value = 't'
            EXCEPT
            SELECT topics.id
            FROM topics
            INNER JOIN topic_custom_fields otc ON topics.id = otc.topic_id
            WHERE (otc.name = '#{CategoryExperts::TOPIC_EXPERT_POST_GROUP_NAMES}' AND
                  otc.value <> '' AND
                  otc.value IS NOT NULL)
      SQL
    end
  end
end
