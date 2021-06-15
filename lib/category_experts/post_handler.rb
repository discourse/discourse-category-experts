# frozen_string_literal: true

module CategoryExperts
  class PostHandler
    attr_accessor :post, :user

    def initialize(post:, user: nil)
      @post = post
      @user = user || post.user
    end

    def process_new_post(skip_validations: false)
      if !skip_validations
        return unless ensure_poster_is_category_expert
      end

      SiteSetting.category_experts_posts_require_approval ?
        mark_post_for_approval(skip_validations: skip_validations) :
        mark_post_as_approved(skip_validations: skip_validations)
    end

    def mark_post_for_approval(skip_validations: false)
      if !skip_validations
        raise Discourse::InvalidParameters unless ensure_poster_is_category_expert
      end

      post_group_name = post.custom_fields[CategoryExperts::POST_APPROVED_GROUP_NAME]

      post.custom_fields.delete(CategoryExperts::POST_APPROVED_GROUP_NAME)
      post.custom_fields[CategoryExperts::POST_PENDING_EXPERT_APPROVAL] = true
      post.save!

      topic = post.topic
      has_accepted_posts_from_same_group = post_group_name && PostCustomField.where(
        post_id: topic.post_ids,
        name: CategoryExperts::POST_APPROVED_GROUP_NAME,
        value: post_group_name
      ).exists?

      unless has_accepted_posts_from_same_group
        groups = (topic.custom_fields[CategoryExperts::TOPIC_EXPERT_POST_GROUP_NAMES]&.split("|") || []) - [post_group_name]

        if groups.any?
          topic.custom_fields[CategoryExperts::TOPIC_EXPERT_POST_GROUP_NAMES] = groups.join("|")
        else
          topic.custom_fields.delete(CategoryExperts::TOPIC_EXPERT_POST_GROUP_NAMES)
        end
      end

      if topic.custom_fields[CategoryExperts::TOPIC_EXPERT_POST_GROUP_NAMES].blank?
        topic.custom_fields[CategoryExperts::TOPIC_NEEDS_EXPERT_POST_APPROVAL] = post.post_number
        topic.custom_fields.delete(CategoryExperts::TOPIC_FIRST_EXPERT_POST_ID)
      else
        topic.custom_fields.delete(CategoryExperts::TOPIC_NEEDS_EXPERT_POST_APPROVAL)
      end

      topic.save!
    end

    def mark_post_as_approved(skip_validations: false)
      if !skip_validations
        raise Discourse::InvalidParameters unless ensure_poster_is_category_expert
      end

      post.custom_fields[CategoryExperts::POST_APPROVED_GROUP_NAME] = users_expert_group.name
      post.custom_fields[CategoryExperts::POST_PENDING_EXPERT_APPROVAL] = false
      post.save!

      topic = post.topic
      topic.custom_fields[CategoryExperts::TOPIC_EXPERT_POST_GROUP_NAMES] =
        (topic.custom_fields[CategoryExperts::TOPIC_EXPERT_POST_GROUP_NAMES]&.split("|") || []).push(users_expert_group.name).uniq.join("|")
      topic.custom_fields.delete(CategoryExperts::TOPIC_NEEDS_EXPERT_POST_APPROVAL)

      if !topic.custom_fields[CategoryExperts::TOPIC_FIRST_EXPERT_POST_ID] ||
          topic.custom_fields[CategoryExperts::TOPIC_FIRST_EXPERT_POST_ID] == 0
        topic.custom_fields[CategoryExperts::TOPIC_FIRST_EXPERT_POST_ID] = post.post_number
      end

      topic.save!
      users_expert_group.name
    end

    def mark_topic_as_question
      topic = post.topic
      raise Discourse::InvalidParameters unless topic.category.accepting_category_expert_questions?

      topic.custom_fields[CategoryExperts::TOPIC_IS_CATEGORY_EXPERT_QUESTION] = true
      topic.save!
    end

    private

    def ensure_poster_is_category_expert
      expert_group_ids.length && users_expert_group
    end

    def expert_group_ids
      unsplit_group_ids = post.topic.category&.custom_fields&.[](CategoryExperts::CATEGORY_EXPERT_GROUP_IDS)
      return [] if unsplit_group_ids.nil?

      unsplit_group_ids.split("|").map(&:to_i)
    end

    def users_expert_group
      return @users_expert_group if defined?(@users_expert_group) # memoizing a potentially falsy value

      group_id = ((expert_group_ids & user.group_ids) || []).first
      @users_expert_group = group_id.nil? ? nil : Group.find_by(id: group_id)
    end
  end
end
