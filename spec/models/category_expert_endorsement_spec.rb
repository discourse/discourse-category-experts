# frozen_string_literal: true

require "rails_helper"

describe CategoryExpertEndorsement do
  fab!(:user) { Fabricate(:user) }
  fab!(:endorsee) { Fabricate(:user) }
  fab!(:other) { Fabricate(:user) }
  fab!(:category1) { Fabricate(:category) }
  fab!(:category2) { Fabricate(:category) }

  describe "#given_endorsements_for" do
    it "returns the proper records" do
      CategoryExpertEndorsement.create(user: user, endorsed_user: endorsee, category: category1)
      CategoryExpertEndorsement.create(user: user, endorsed_user: endorsee, category: category2)

      expect(user.given_category_expert_endorsements_for(other)).to eq([])
      expect(user.given_category_expert_endorsements_for(endorsee).count).to eq(2)
    end
  end

  describe "valdations" do
    it "validates that the user_id and endorsed_user_id are different" do
      endorsement =
        CategoryExpertEndorsement.new(user: user, endorsed_user: user, category: category1)
      endorsement.valid?
      expect(endorsement.errors[:user_id]).to be_present
    end
  end

  describe "callbacks" do
    it "creates a reviewable if the new endorsement count matches the site setting" do
      SiteSetting.category_expert_suggestion_threshold = 1

      expect {
        CategoryExpertEndorsement.create(user: user, endorsed_user: endorsee, category: category1)
      }.to change { Reviewable.count }.by(1)
    end

    it "does not create a reviewable if the new count does not match the site setting" do
      SiteSetting.category_expert_suggestion_threshold = 3

      expect {
        CategoryExpertEndorsement.create(user: user, endorsed_user: endorsee, category: category1)
      }.not_to change { Reviewable.count }
    end
  end
end
