# frozen_string_literal: true

module Jobs
  class CorrectHistoricalCategoryExpertPosts < ::Jobs::Base

    sidekiq_options queue: 'low'

    def execute(args = {})
      return unless SiteSetting.approve_past_posts_on_becoming_category_expert

      CategoryCustomField
        .where(name: CategoryExperts::CATEGORY_EXPERT_GROUP_IDS)
        .where.not(value: nil)
        .where.not(value: "")
        .pluck(:category_id, :value)
        .each do |category_id, group_ids|
          groups = Group.where(id: group_ids)
          user_ids = groups.map(&:user_ids).flatten.uniq
          next if user_ids.blank?

          posts = Post.joins(:topic)
            .where(user_id: user_ids)
            .where(topic: { category_id: category_id })

          posts.each do |post|
            begin
              CategoryExperts::PostHandler
                .new(post: post)
                .process_new_post(skip_validations: true)
            rescue
              Rails.logger.warn("Error saving post with ID #{post.id} in correct_historical_category_expert_posts job")
              next
            end
          end
        end
    end
  end
end
