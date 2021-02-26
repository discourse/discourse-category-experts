# frozen_string_literal: true

require_dependency 'reviewable'

class ReviewableCategoryExpertSuggestion < Reviewable
  def build_actions(actions, guardian, _args)
    return [] unless pending?

    actions.add(:approve_category_expert) do |action|
      action.icon = 'thumbs-up'
      action.label = "js.category_experts.review.approve"
    end

    actions.add(:deny_category_expert) do |action|
      action.icon = 'thumbs-down'
      action.label = "js.category_experts.review.deny"
      action.button_class = 'btn-danger'
    end
  end

  def perform_approve_category_expert(performed_by, _args)

    create_result(:success, :approve)
  end

  def perform_deny_category_expert(performed_by, _args)

    create_result(:success, :deleted)
  end
end
