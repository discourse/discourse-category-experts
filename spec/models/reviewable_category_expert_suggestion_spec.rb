# frozen_string_literal: true

require "rails_helper"

describe ReviewableCategoryExpertSuggestion do
  fab!(:admin) { Fabricate(:admin) }
  fab!(:user) { Fabricate(:user) }
  fab!(:category) { Fabricate(:category) }
  fab!(:group) { Fabricate(:group) }
  let(:category_expert_endorsement) {
    CategoryExpertEndorsement.create(
      user: admin,
      endorsed_user: user,
      category: category
    )
  }

  let(:reviewable) do
    ReviewableCategoryExpertSuggestion.needs_review!(
      target: category_expert_endorsement, created_by: Discourse.system_user
    )
  end

  before do
    SiteSetting.enable_category_experts = true
    category.custom_fields[CategoryExperts::CATEGORY_EXPERT_GROUP_IDS] = group.id.to_s
    category.custom_fields[CategoryExperts::CATEGORY_ACCEPTING_ENDORSEMENTS] = true
  end

  describe "#perform_approve_category_expert" do
    it "adds the user to the group" do
      expect(user.group_ids).to eq([])
      reviewable.perform(admin, :approve_category_expert, group_id: group.id)

      expect(user.reload.group_ids).to eq([group.id])
      expect(reviewable.status).to eq(Reviewable.statuses[:approved])
    end
  end

  describe "#perform_deny_category_expert" do
    it "does not add the user to the group, and rejects the reviewable" do
      expect(user.group_ids).to eq([])
      reviewable.perform(admin, :deny_category_expert)

      expect(user.reload.group_ids).to eq([])
      expect(reviewable.status).to eq(Reviewable.statuses[:rejected])
    end
  end
end
