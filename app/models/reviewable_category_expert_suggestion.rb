# frozen_string_literal: true

require_dependency 'reviewable'

class ReviewableCategoryExpertSuggestion < Reviewable
  def build_actions(actions, guardian, _args)
    return [] unless pending?

    actions.add(:approve_category_expert) do |action|
      action.icon = 'thumbs-up'
      action.custom_modal = 'expert-group-chooser'
      action.label = "js.category_experts.review.approve"
    end

    actions.add(:deny_category_expert) do |action|
      action.icon = 'thumbs-down'
      action.label = "js.category_experts.review.deny"
      action.button_class = 'btn-danger'
    end
  end

  def perform_approve_category_expert(performed_by, args)
    group_id = args.symbolize_keys[:group_id]

    possible_group_ids = target.category.custom_fields[CategoryExperts::CATEGORY_EXPERT_GROUP_IDS].split("|").map(&:to_i)
    raise Discourse::NotFound unless possible_group_ids.include?(group_id.to_i)

    group = Group.find_by(id: group_id)
    group.add(target.endorsed_user)

    create_result(:success, :approved)
  end

  def perform_deny_category_expert(performed_by, _args)
    create_result(:success, :rejected)
  end
end
