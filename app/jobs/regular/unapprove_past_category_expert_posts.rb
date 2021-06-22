# frozen_string_literal: true

module Jobs
  class UnapprovePastCategoryExpertPosts < ::Jobs::Base

    sidekiq_options queue: 'low'

    def execute(args)
      unless args[:user_id].kind_of?(Integer)
        raise Discourse::InvalidParameters.new(:user_id)
      end

      unless args[:category_ids].kind_of?(Array)
        raise Discourse::InvalidParameters.new(:category_ids)
      end

      user = User.find_by(id: args[:user_id])
      raise Discourse::InvalidParameters.new(:user_id) unless user

      # The user was removed as category expert from 1 group. They could
      # still be a category expert by another group memebership.
      # Filter out those categories.
      categories = Category.where(id: args[:category_ids]).filter do |c|
        user.expert_group_ids_for_category(c).empty?
      end

      posts = Post
        .joins(:topic)
        .joins("LEFT OUTER JOIN post_custom_fields AS pcf ON pcf.post_id = posts.id")
        .where("pcf.name = ? or pcf.name = ?",
               CategoryExperts::POST_APPROVED_GROUP_NAME,
               CategoryExperts::POST_PENDING_EXPERT_APPROVAL)
        .where(user_id: user.id)
        .where(topic: { category_id: categories.map(&:id) })

      posts.group_by(&:topic).each do |topic, grouped_posts|
        grouped_posts.each do |post|
          if SiteSetting.approve_past_posts_on_becoming_category_expert
            post.custom_fields.delete(CategoryExperts::POST_APPROVED_GROUP_NAME)
          end
          post.custom_fields.delete(CategoryExperts::POST_PENDING_EXPERT_APPROVAL)
          post.save
        end

        if SiteSetting.approve_past_posts_on_becoming_category_expert
          other_approved_post_count = PostCustomField
            .where(post_id: topic.post_ids)
            .where(name: CategoryExperts::POST_APPROVED_GROUP_NAME)
            .count

          if other_approved_post_count == 0
            topic.custom_fields.delete(CategoryExperts::TOPIC_EXPERT_POST_GROUP_NAMES)
            topic.save
          end
        end
      end
    end
  end
end
