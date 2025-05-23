# frozen_string_literal: true

module CategoryExperts
  class PostHandler
    attr_accessor :post, :topic, :user

    def initialize(post: nil, topic: nil, user: nil)
      @post = post
      @topic = topic || post&.topic
      @user = user || post&.user
    end

    def process_new_post(skip_validations: false, previously_approved: false)
      if !skip_validations
        return unless ensure_poster_is_category_expert
      end

      return unless post.post_type == Post.types[:regular]

      return mark_post_as_approved(skip_validations: skip_validations) if previously_approved

      if SiteSetting.category_experts_posts_require_approval
        mark_post_for_approval(skip_validations: skip_validations)
      else
        mark_post_as_approved(skip_validations: skip_validations)
      end
    end

    def mark_post_for_approval(skip_validations: false, new_post: true)
      if !skip_validations
        raise Discourse::InvalidParameters unless ensure_poster_is_category_expert
      end
      should_remove_auto_tag = false

      post_group_name = post.custom_fields[CategoryExperts::POST_APPROVED_GROUP_NAME]

      post.custom_fields.delete(CategoryExperts::POST_APPROVED_GROUP_NAME)
      post.custom_fields[CategoryExperts::POST_PENDING_EXPERT_APPROVAL] = true
      post.save!

      correct_topic_custom_fields_after_removal(group_name: post_group_name, new_post: new_post)
    end

    def mark_post_as_approved(skip_validations: false, new_post: true)
      if !skip_validations
        raise Discourse::InvalidParameters unless ensure_poster_is_category_expert
      end

      # if this is not the topic post (post>1) OR it's the topic post/first post and it's ok for that to be an expert post
      return unless post.post_number > 1 || SiteSetting.first_post_can_be_considered_expert_post

      post.custom_fields[CategoryExperts::POST_APPROVED_GROUP_NAME] = users_expert_group.name
      post.custom_fields[CategoryExperts::POST_PENDING_EXPERT_APPROVAL] = false
      post.save!

      correct_topic_custom_fields_after_addition(new_post: new_post)

      users_expert_group.name
    end

    def mark_topic_as_question
      topic = post.topic
      raise Discourse::InvalidParameters unless topic.category.accepting_category_expert_questions?

      topic.custom_fields[CategoryExperts::TOPIC_IS_CATEGORY_EXPERT_QUESTION] = true
      topic.save!
    end

    def correct_topic_custom_fields_after_removal(group_name:, new_post: false)
      has_accepted_posts_from_same_group =
        group_name &&
          PostCustomField.where(
            post_id: topic.post_ids,
            name: CategoryExperts::POST_APPROVED_GROUP_NAME,
            value: group_name,
          ).exists?

      if !has_accepted_posts_from_same_group
        groups =
          (topic.custom_fields[CategoryExperts::TOPIC_EXPERT_POST_GROUP_NAMES]&.split("|") || []) -
            [group_name]

        if groups.any?
          topic.custom_fields[CategoryExperts::TOPIC_EXPERT_POST_GROUP_NAMES] = groups.join("|")
        else
          topic.custom_fields.delete(CategoryExperts::TOPIC_EXPERT_POST_GROUP_NAMES)
        end
      end

      if topic.custom_fields[CategoryExperts::TOPIC_EXPERT_POST_GROUP_NAMES].blank?
        if post
          topic.custom_fields[CategoryExperts::TOPIC_NEEDS_EXPERT_POST_APPROVAL] = post.post_number
        end
        topic.custom_fields.delete(CategoryExperts::TOPIC_FIRST_EXPERT_POST_ID)
        should_remove_auto_tag = true
      else
        topic.custom_fields.delete(CategoryExperts::TOPIC_NEEDS_EXPERT_POST_APPROVAL)
      end

      topic.save!

      DiscourseEvent.trigger(:category_experts_unapproved, post) if post && !new_post

      remove_auto_tag if should_remove_auto_tag
    end

    def correct_topic_custom_fields_after_addition(new_post: false)
      topic.custom_fields[CategoryExperts::TOPIC_EXPERT_POST_GROUP_NAMES] = (
        topic.custom_fields[CategoryExperts::TOPIC_EXPERT_POST_GROUP_NAMES]&.split("|") || []
      ).push(users_expert_group.name).uniq.join("|")
      topic.custom_fields.delete(CategoryExperts::TOPIC_NEEDS_EXPERT_POST_APPROVAL)

      if !topic.custom_fields[CategoryExperts::TOPIC_FIRST_EXPERT_POST_ID] ||
           topic.custom_fields[CategoryExperts::TOPIC_FIRST_EXPERT_POST_ID] == 0
        topic.custom_fields[CategoryExperts::TOPIC_FIRST_EXPERT_POST_ID] = post.post_number
      end

      topic.save!

      DiscourseEvent.trigger(:category_experts_approved, post) unless new_post

      add_auto_tag
    end

    private

    def ensure_poster_is_category_expert
      !users_expert_group.nil?
    end

    def users_expert_group
      return @users_expert_group if defined?(@users_expert_group) # memoizing a potentially falsy value
      category = post.topic&.category
      return if !category

      group_id = user.expert_group_ids_for_category(category)&.first
      @users_expert_group = group_id.nil? ? nil : Group.find_by(id: group_id)
    end

    def add_auto_tag
      return if !SiteSetting.tagging_enabled
      return if auto_tag_for_category.blank?

      existing_tag_names = topic.tags.map(&:name)
      # Return early if the topic already has the automatic tag
      return if existing_tag_names.include?(auto_tag_for_category)

      PostRevisor.new(topic.ordered_posts.first).revise!(
        Discourse.system_user,
        { tags: (existing_tag_names << auto_tag_for_category) },
      )
    end

    def remove_auto_tag
      return if !SiteSetting.tagging_enabled
      return if auto_tag_for_category.blank?

      existing_tag_names = topic.tags.map(&:name)
      # Return early if the topic doesn't have the automatic tag
      return if !existing_tag_names.include?(auto_tag_for_category)

      PostRevisor.new(topic.ordered_posts.first).revise!(
        Discourse.system_user,
        { tags: ((existing_tag_names || []) - [auto_tag_for_category]) },
      )
    end

    def auto_tag_for_category
      return @auto_tag_for_category if defined?(@auto_tag_for_category)

      @auto_tag_for_category =
        @topic.category.custom_fields[CategoryExperts::CATEGORY_EXPERT_AUTO_TAG]
    end
  end
end
