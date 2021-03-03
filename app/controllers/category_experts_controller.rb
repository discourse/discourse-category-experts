# frozen_string_literal: true

class CategoryExpertsController < ApplicationController

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
end
