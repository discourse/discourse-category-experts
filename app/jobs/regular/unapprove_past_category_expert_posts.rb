# frozen_string_literal: true

module Jobs
  class UnapprovePastCategoryExpertPosts < ::Jobs::Base

    sidekiq_options queue: 'low'

    def execute(args)
      return unless SiteSetting.approve_past_posts_on_becoming_category_expert

      unless args[:user_id].kind_of?(Integer)
        raise Discourse::InvalidParameters.new(:user_id)
      end

      unless args[:category_ids].kind_of?(Array)
        raise Discourse::InvalidParameters.new(:category_ids)
      end

      user = User.find_by(args[:user_id])
      raise Discourse::InvalidParameters.new(:user_id) unless user

      category_ids = args[:category_ids].select do |category_id|
        category = category.find_by(id: category_id)
      end


      posts = Post.joins(:topic)
        .where(user_id: args[:user_id])
        .where(topic: { category_id: args[:category_ids] })

      posts.group_by(&:topic).each do |topic, grouped_posts|
        grouped_posts.each do |post|
          post.custom_fields.delete(CategoryExperts::POST_APPROVED_GROUP_NAME)
          post.custom_fields.delete(CategoryExperts::POST_PENDING_EXPERT_APPROVAL)
          post.save
        end

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
