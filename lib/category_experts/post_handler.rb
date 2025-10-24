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

    def handle_topic_category_change(old_category_id, new_category_id)
      old_category = Category.find_by(id: old_category_id)
      new_category = Category.find_by(id: new_category_id)

      # Get auto-tags before processing posts
      old_auto_tag = old_category&.custom_fields&.[](CategoryExperts::CATEGORY_EXPERT_AUTO_TAG)
      new_auto_tag = new_category&.custom_fields&.[](CategoryExperts::CATEGORY_EXPERT_AUTO_TAG)

      # Get all posts in the topic that have expert status
      expert_posts =
        Post
          .includes(:user)
          .joins(:_custom_fields)
          .where(
            topic_id: topic.id,
            post_custom_fields: {
              name: CategoryExperts::POST_APPROVED_GROUP_NAME,
            },
          )
          .where.not(post_custom_fields: { value: nil })

      # Re-evaluate each expert post
      expert_posts.each do |expert_post|
        post_author = expert_post.user
        next if !post_author

        # Check if the post author is an expert in the new category
        author_expert_group_ids = post_author.expert_group_ids_for_category(new_category)

        if author_expert_group_ids.empty?
          # Author is no longer an expert - remove expert status
          old_group_name = expert_post.custom_fields[CategoryExperts::POST_APPROVED_GROUP_NAME]
          expert_post.custom_fields.delete(CategoryExperts::POST_APPROVED_GROUP_NAME)
          expert_post.custom_fields.delete(CategoryExperts::POST_PENDING_EXPERT_APPROVAL)
          expert_post.save!

          # Update topic custom fields to reflect the removal
          CategoryExperts::PostHandler.new(
            post: expert_post,
            topic: topic,
          ).correct_topic_custom_fields_after_removal(group_name: old_group_name)
        else
          # Author is still an expert in the new category - update the group name
          new_expert_group = Group.find_by(id: author_expert_group_ids.first)
          old_group_name = expert_post.custom_fields[CategoryExperts::POST_APPROVED_GROUP_NAME]

          if new_expert_group && new_expert_group.name != old_group_name
            # Update post with new group name first
            expert_post.custom_fields[
              CategoryExperts::POST_APPROVED_GROUP_NAME
            ] = new_expert_group.name
            expert_post.save!

            # Remove old group from topic custom fields (now that post is updated)
            CategoryExperts::PostHandler.new(
              post: expert_post,
              topic: topic,
            ).correct_topic_custom_fields_after_removal(group_name: old_group_name)

            # Add new group to topic custom fields
            CategoryExperts::PostHandler.new(
              post: expert_post,
              topic: topic,
              user: post_author,
            ).correct_topic_custom_fields_after_addition
          end
        end
      end

      # Handle auto-tag swapping for category change
      handle_auto_tag_swap(old_auto_tag, new_auto_tag)
    end

    private

    def handle_auto_tag_swap(old_auto_tag, new_auto_tag)
      return if !SiteSetting.tagging_enabled

      # Reload topic to get latest custom fields
      topic.reload

      existing_tag_names = topic.tags.map(&:name)
      modified = false

      # Remove old auto-tag if present
      if old_auto_tag.present? && existing_tag_names.include?(old_auto_tag)
        existing_tag_names = existing_tag_names - [old_auto_tag]
        modified = true
      end

      # Add new auto-tag if tag is configured and new category has expert groups
      # (regardless of whether there are currently expert posts, since the topic
      # had expert posts in the previous category)
      new_category_has_experts =
        topic.category.custom_fields[CategoryExperts::CATEGORY_EXPERT_GROUP_IDS].present?
      if new_auto_tag.present? && new_category_has_experts &&
           !existing_tag_names.include?(new_auto_tag)
        existing_tag_names = existing_tag_names + [new_auto_tag]
        modified = true
      end

      # Only revise if tags were modified
      if modified
        PostRevisor.new(topic.ordered_posts.first).revise!(
          Discourse.system_user,
          { tags: existing_tag_names },
        )
      end
    end

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
