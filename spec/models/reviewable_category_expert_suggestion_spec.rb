# frozen_string_literal: true

require "rails_helper"

describe ReviewableCategoryExpertSuggestion do
  fab!(:admin) { Fabricate(:admin) }
  fab!(:user) { Fabricate(:user) }
  fab!(:category) { Fabricate(:category) }
  fab!(:group) { Fabricate(:group) }
  let(:category_expert_endorsement) do
    CategoryExpertEndorsement.create(user: admin, endorsed_user: user, category: category)
  end

  let(:reviewable) do
    ReviewableCategoryExpertSuggestion.needs_review!(
      target: category_expert_endorsement,
      created_by: Discourse.system_user,
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
      expect { reviewable.perform(admin, :approve_category_expert, group_id: group.id) }.to change {
        Topic.where(archetype: Archetype.private_message).count
      }.by(1)

      expect(user.reload.group_ids).to eq([group.id])
      expect(reviewable).to be_approved
    end

    it "grants the user the categories badge when present" do
      badge = Badge.create!(name: "a badge", badge_type_id: BadgeType::Bronze)
      category.custom_fields[CategoryExperts::CATEGORY_BADGE_ID] = badge.id
      reviewable.perform(admin, :approve_category_expert, group_id: group.id)

      expect(UserBadge.find_by(user_id: user.id, badge_id: badge.id)).not_to eq(nil)
    end
  end

  describe "#perform_deny_category_expert" do
    it "does not add the user to the group, and rejects the reviewable" do
      expect(user.group_ids).to eq([])
      reviewable.perform(admin, :deny_category_expert)

      expect(user.reload.group_ids).to eq([])
      expect(reviewable).to be_rejected
    end
  end
end
