# frozen_string_literal: true

require_dependency "reviewable"

class ReviewableCategoryExpertSuggestion < Reviewable
  def build_actions(actions, guardian, _args)
    return [] unless pending?

    actions.add(:approve_category_expert) do |action|
      action.icon = "thumbs-up"
      action.label = "js.category_experts.review.approve"
    end

    actions.add(:deny_category_expert) do |action|
      action.icon = "thumbs-down"
      action.label = "js.category_experts.review.deny"
      action.button_class = "btn-danger"
    end
  end

  def perform_approve_category_expert(performed_by, args)
    group_id = args.symbolize_keys[:group_id]

    category = target.category
    possible_group_ids =
      category.custom_fields[CategoryExperts::CATEGORY_EXPERT_GROUP_IDS].split("|").map(&:to_i)
    raise Discourse::NotFound if possible_group_ids.exclude?(group_id.to_i)

    group = Group.find_by(id: group_id)
    group.add(target.endorsed_user)
    notify_user(target.endorsed_user, category, group)
    grant_badge(target.endorsed_user, category)

    create_result(:success, :approved)
  end

  def perform_deny_category_expert(performed_by, _args)
    create_result(:success, :rejected)
  end

  private

  def grant_badge(user, category)
    badge = Badge.find_by(id: category.custom_fields[CategoryExperts::CATEGORY_BADGE_ID])
    return unless badge

    BadgeGranter.grant(badge, user)
  end

  def notify_user(user, category, group)
    SystemMessage.create_from_system_user(
      user,
      :user_add_as_category_expert,
      category_name: category.name,
      category_url: category.url,
      group_name: group.full_name.presence || group.name,
      group_path: "/g/#{group.name}",
    )
  end
end

# == Schema Information
#
# Table name: reviewables
#
#  id                      :bigint           not null, primary key
#  type                    :string           not null
#  status                  :integer          default("pending"), not null
#  created_by_id           :integer          not null
#  reviewable_by_moderator :boolean          default(FALSE), not null
#  category_id             :integer
#  topic_id                :integer
#  score                   :float            default(0.0), not null
#  potential_spam          :boolean          default(FALSE), not null
#  target_id               :integer
#  target_type             :string
#  target_created_by_id    :integer
#  payload                 :json
#  version                 :integer          default(0), not null
#  latest_score            :datetime
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  force_review            :boolean          default(FALSE), not null
#  reject_reason           :text
#  potentially_illegal     :boolean          default(FALSE)
#  type_source             :string           default("unknown"), not null
#
# Indexes
#
#  idx_reviewables_score_desc_created_at_desc                  (score,created_at)
#  index_reviewables_on_reviewable_by_group_id                 (reviewable_by_group_id)
#  index_reviewables_on_status_and_created_at                  (status,created_at)
#  index_reviewables_on_status_and_score                       (status,score)
#  index_reviewables_on_status_and_type                        (status,type)
#  index_reviewables_on_target_id_where_post_type_eq_post      (target_id) WHERE ((target_type)::text = 'Post'::text)
#  index_reviewables_on_topic_id_and_status_and_created_by_id  (topic_id,status,created_by_id)
#  index_reviewables_on_type_and_target_id                     (type,target_id) UNIQUE
#
