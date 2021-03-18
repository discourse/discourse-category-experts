# frozen_string_literal: true

class CategoryExpertsController < ApplicationController
  before_action :find_post, :ensure_staff_and_enabled, only: [:approve_post, :unapprove_post]
  before_action :find_topic, only: [:mark_topic_as_question, :unmark_topic_as_question]

  def endorse
    raise Discourse::NotFound unless current_user
    user = fetch_user_from_params

    category_ids = params[:categoryIds]&.reject(&:blank?)

    raise Discourse::InvalidParameters if category_ids.blank?

    categories = Category.where(id: category_ids)
    categories.each do |category|
      raise Discourse::InvalidParameters unless category.accepting_category_expert_endorsements?

      CategoryExpertEndorsement.find_or_create_by(user: current_user, endorsed_user: user, category: category)
    end

    render json: {
      category_expert_endorsements: current_user.given_category_expert_endorsements_for(user)
    }.to_json
  end

  def approve_post
    post_handler = CategoryExperts::PostHandler.new(post: @post)
    group_name = post_handler.mark_post_as_approved

    render json: {
      group_name: group_name
    }.merge(topic_custom_fields)
  end

  def unapprove_post
    post_handler = CategoryExperts::PostHandler.new(post: @post)
    post_handler.mark_post_for_approval

    render json: topic_custom_fields
  end

  def mark_topic_as_question
    guardian.ensure_can_edit!(@topic)
    raise Discourse::InvalidParameters unless @topic.category.accepting_category_expert_questions?

    @topic.custom_fields[CategoryExperts::TOPIC_IS_CATEGORY_EXPERT_QUESTION] = true
    @topic.save!

    render json: success_json
  end

  def unmark_topic_as_question
    guardian.ensure_can_edit!(@topic)

    @topic.custom_fields[CategoryExperts::TOPIC_IS_CATEGORY_EXPERT_QUESTION] = false
    @topic.save!

    render json: success_json
  end

  private

  def topic_custom_fields
    {
      topic_expert_post_group_names: @post.topic.custom_fields[CategoryExperts::TOPIC_EXPERT_POST_GROUP_NAMES],
      topic_needs_category_expert_approval: @post.topic.custom_fields[CategoryExperts::TOPIC_NEEDS_EXPERT_POST_APPROVAL]
    }
  end

  def ensure_staff_and_enabled
    unless current_user && current_user.staff? && SiteSetting.category_experts_posts_require_approval
      raise Discourse::InvalidAccess
    end
  end

  def find_post
    post_id = params.require(:post_id)
    @post = Post.find_by(id: post_id)

    raise Discourse::NotFound unless @post
  end

  def find_topic
    topic_id = params.require(:topic_id)
    @topic = Topic.find_by(id: topic_id)

    raise Discourse::NotFound unless @topic
  end
end
