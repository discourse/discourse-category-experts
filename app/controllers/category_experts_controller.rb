# frozen_string_literal: true

class CategoryExpertsController < ApplicationController
  before_action :find_post, :ensure_staff_and_enabled, only: [:approve_post, :unapprove_post]

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

    render json: { group_name: group_name }
  end

  def unapprove_post
    post_handler = CategoryExperts::PostHandler.new(post: @post)
    post_handler.mark_post_for_approval

    render json: success_json
  end

  private

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
end
