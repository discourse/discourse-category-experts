# frozen_string_literal: true

module Jobs
  class ApprovePastCategoryExpertPosts < ::Jobs::Base

    sidekiq_options queue: 'low'

    def execute(args)
      return unless SiteSetting.approve_past_posts_on_becoming_category_expert

      unless args[:user_id].kind_of?(Integer)
        raise Discourse::InvalidParameters.new(:user_id)
      end

      unless args[:category_ids].kind_of?(Array)
        raise Discourse::InvalidParameters.new(:category_ids)
      end

      posts = Post.joins(:topic)
        .where(user_id: args[:user_id])
        .where(topic: { category_id: args[:category_ids] })

      posts.each do |post|
        CategoryExperts::PostHandler.new(post: post).process_new_post(skip_validations: true)
      end
    end
  end
end
