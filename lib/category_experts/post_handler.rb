# frozen_string_literal: true

module CategoryExperts
  class PostHandler
    attr_accessor :post, :user

    def initialize(post:, user: nil)
      @post = post
      @user = user || post.user
    end

    def process_new_post
      return unless ensure_correct_settings

      SiteSetting.category_experts_posts_require_approval ?
        mark_post_for_approval :
        mark_post_as_approved
    end

    def mark_post_for_approval
      raise Discourse::InvalidParameters unless ensure_correct_settings

      post.custom_fields[CategoryExperts::POST_APPROVED_GROUP_NAME] = nil
      post.custom_fields[CategoryExperts::POST_PENDING_EXPERT_APPROVAL] = true
      post.save

      topic = post.topic
      unless topic.custom_fields[CategoryExperts::TOPIC_HAS_APPROVED_EXPERT_POST]
        # Topic doesn't have any approved expert posts. Mark as needing approval
        topic.custom_fields[CategoryExperts::TOPIC_NEEDS_EXPERT_POST_APPROVAL] = true
        topic.save
      end
    end

    def mark_post_as_approved
      raise Discourse::InvalidParameters unless ensure_correct_settings

      post.custom_fields[CategoryExperts::POST_APPROVED_GROUP_NAME] = users_expert_group.name
      post.custom_fields[CategoryExperts::POST_PENDING_EXPERT_APPROVAL] = nil
      post.save

      topic = post.topic
      topic.custom_fields[CategoryExperts::TOPIC_HAS_APPROVED_EXPERT_POST] = true
      topic.custom_fields[CategoryExperts::TOPIC_NEEDS_EXPERT_POST_APPROVAL] = nil
      topic.save

      users_expert_group.name
    end

    private

    def ensure_correct_settings
      expert_group_ids.length && users_expert_group
    end

    def expert_group_ids
      unsplit_group_ids = post.topic.category.custom_fields[CategoryExperts::CATEGORY_EXPERT_GROUP_IDS]
      return [] if unsplit_group_ids.nil?

      unsplit_group_ids.split("|").map(&:to_i)
    end

    def users_expert_group
      return @users_expert_group if defined?(@users_expert_group) # memoizing a potentially falsy value

      group_id = ((expert_group_ids & user.group_ids) || []).first
      return nil if group_id.nil?

      @users_expert_group = Group.find_by(id: group_id)
    end
  end
end
