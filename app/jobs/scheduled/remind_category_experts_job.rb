# frozen_string_literal: true

class RemindCategoryExpertsJob < ::Jobs::Scheduled
  every 1.day

  def execute(args)
    category_custom_fields = CategoryCustomField
      .where(name: CategoryExperts::CATEGORY_EXPERT_GROUP_IDS)
      .where.not(value: nil)

    group_ids = category_custom_fields
      .map(&:value)
      .flat_map { |ids| ids.split("|") }
      .uniq

    users = User
      .joins(:group_users)
      .where(group_users: { group_id: group_ids })

  end
end
