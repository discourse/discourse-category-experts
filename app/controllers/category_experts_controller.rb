# frozen_string_literal: true

class CategoryExpertsController < ApplicationController
  before_action :find_post,
                :ensure_staff,
                :ensure_needs_approval_enabled,
                only: %i[approve_post unapprove_post retroactive_approval?]
  before_action :ensure_needs_approval_enabled, only: %i[approve_post unapprove_post]
  before_action :authenticate_and_find_user, only: %i[endorse endorsable_categories]

  def endorse
    CategoryExperts::EndorsementRateLimiter.new(current_user).performed!
    category_ids = params[:categoryIds]&.reject(&:blank?)

    raise Discourse::InvalidParameters if category_ids.blank?

    categories = Category.where(id: category_ids)
    categories.each do |category|
      raise Discourse::InvalidParameters unless category.accepting_category_expert_endorsements?

      CategoryExpertEndorsement.find_or_create_by(
        user: current_user,
        endorsed_user: @user,
        category: category,
      )
    end

    render json: {
             category_expert_endorsements:
               current_user.given_category_expert_endorsements_for(@user),
           }.to_json
  end

  def endorsable_categories
    endorsee_guardian = Guardian.new(@user)

    categories =
      Category.where(
        id:
          CategoryCustomField
            .where(name: CategoryExperts::CATEGORY_ACCEPTING_ENDORSEMENTS)
            .true_fields
            .select(:category_id),
      ).where(
        id:
          CategoryCustomField
            .where(name: CategoryExperts::CATEGORY_EXPERT_GROUP_IDS)
            .where.not(value: "")
            .select(:category_id),
      )

    categories =
      categories.select do |category|
        guardian.can_see_category?(category) && endorsee_guardian.can_see_category?(category)
      end

    render_serialized(
      categories,
      BasicCategorySerializer,
      root: :categories,
      rest_serializer: true,
      extras: {
        remaining_endorsements: CategoryExperts::EndorsementRateLimiter.new(current_user).remaining,
      },
    )
  end

  def approve_post
    post_handler = CategoryExperts::PostHandler.new(post: @post)
    group_name = post_handler.mark_post_as_approved

    render json: { group_name: group_name }.merge(topic_custom_fields)
  end

  def unapprove_post
    post_handler = CategoryExperts::PostHandler.new(post: @post)
    post_handler.mark_post_for_approval

    render json: topic_custom_fields
  end

  def retroactive_approval?
    render json: { can_be_approved: post_could_be_expert_answer(@post) }
  end

  private

  def post_could_be_expert_answer(post)
    return false if post.custom_fields[CategoryExperts::POST_APPROVED_GROUP_NAME]

    category = post.topic.category
    return false unless category

    expert_group_ids =
      category.custom_fields[CategoryExperts::CATEGORY_EXPERT_GROUP_IDS]&.split("|")&.map(&:to_i)
    return false if expert_group_ids.nil? || expert_group_ids.count == 0

    (expert_group_ids & (post.user.group_ids || [])).count > 0
  end

  def topic_custom_fields
    {
      topic_expert_post_group_names:
        @post.topic.custom_fields[CategoryExperts::TOPIC_EXPERT_POST_GROUP_NAMES]&.split("|"),
      topic_needs_category_expert_approval:
        @post.topic.custom_fields[CategoryExperts::TOPIC_NEEDS_EXPERT_POST_APPROVAL],
    }
  end

  def ensure_staff_and_enabled
    raise Discourse::InvalidAccess unless current_user && current_user.staff?
  end

  def ensure_needs_approval_enabled
    raise Discourse::InvalidAccess unless SiteSetting.category_experts_posts_require_approval
  end

  def find_post
    post_id = params.require(:post_id)
    @post = Post.find_by(id: post_id)

    raise Discourse::NotFound unless @post
  end

  def authenticate_and_find_user
    raise Discourse::NotFound unless current_user

    @user = fetch_user_from_params
  end
end
