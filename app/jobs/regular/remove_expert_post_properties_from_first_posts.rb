# frozen_string_literal: true

module Jobs
  class RemoveExpertPostPropertiesFromFirstPosts < ::Jobs::Base
    sidekiq_options queue: "low"

    def fix_post(post)
      return if !post
      return if post.post_number!=1


      post_group_name = post.custom_fields[CategoryExperts::POST_APPROVED_GROUP_NAME]

      # remove category experts group name and pending approval flag
      post.custom_fields.delete(CategoryExperts::POST_APPROVED_GROUP_NAME)
      post.custom_fields.delete(CategoryExperts::POST_PENDING_EXPERT_APPROVAL)
      post.save!

      # ok we've removed the custom field from the post, now time to tackle the
      # topic expert-group custom field.
      # first make sure some *other* post doesn't have the same (approved) expert group
      topic = post.topic
      return unless topic

      has_accepted_posts_from_same_group =
        post_group_name &&
          PostCustomField.where(
            post_id: topic.post_ids,
            name: CategoryExperts::POST_APPROVED_GROUP_NAME,
            value: post_group_name,
          ).exists?

      # if there are no posts from this group that were otherwise approved in the topic,
      # remove the expert group name from the custom fields
      if !has_accepted_posts_from_same_group
        groups =
          (topic.custom_fields[CategoryExperts::TOPIC_EXPERT_POST_GROUP_NAMES]&.split("|") || []) -
            [post_group_name]
        if groups.any?
          topic.custom_fields[CategoryExperts::TOPIC_EXPERT_POST_GROUP_NAMES] = groups.join("|")
        else
          topic.custom_fields.delete(CategoryExperts::TOPIC_EXPERT_POST_GROUP_NAMES)
        end
      end

      # if the first_expert_topic_id is 1, delete that custom_field.
      if topic.custom_fields[CategoryExperts::TOPIC_FIRST_EXPERT_POST_ID]==1
        topic.custom_fields.delete(CategoryExperts::TOPIC_FIRST_EXPERT_POST_ID)
      end
      topic.save!
    end

    def execute(args={})
      Post
         .joins("inner JOIN post_custom_fields AS pcf ON pcf.post_id = posts.id")
         .where(post_number:1)
         .where("pcf.name=?",CategoryExperts::POST_APPROVED_GROUP_NAME)
      .map { |post|
        fix_post(post)
      }
    end
  end
end
