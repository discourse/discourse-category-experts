# frozen_string_literal: true

require "rails_helper"

describe CategoryExpertsController do
  fab!(:user) { Fabricate(:user) }
  fab!(:endorsee) { Fabricate(:user) }
  fab!(:category1) { fabricate_category_with_category_experts }
  fab!(:category2) { fabricate_category_with_category_experts }

  def fabricate_category_with_category_experts
    category = Fabricate(:category)
    enable_accepting_questions_for(category)
    set_expert_group_for_category(category, Fabricate(:group))
    category.save
    category
  end

  def enable_accepting_questions_for(category)
    category.custom_fields[CategoryExperts::CATEGORY_ACCEPTING_ENDORSEMENTS] = true
  end

  def set_expert_group_for_category(category, group)
    category.custom_fields[CategoryExperts::CATEGORY_EXPERT_GROUP_ID] = group.id
  end

  describe "#endorse" do
    it "errors when the current user is not logged in" do
      put("/category-experts/endorse/#{endorsee.username}.json", params: { categoryIds: [category1.id] })
      expect(response.status).to eq(404)
    end

    context "logged in" do
      before do
        sign_in(user)
      end

      it "errors when no category ids are present" do
        put("/category-experts/endorse/#{endorsee.username}.json", params: { categoryIds: [] })
        expect(response.status).to eq(400)
      end

      it "errors when the category isn't accepting endorsements" do
        category = Fabricate(:category)
        put("/category-experts/endorse/#{endorsee.username}.json", params: { categoryIds: [category.id] })
        expect(response.status).to eq(400)
      end

      it "creates new UserEndorsement records for each category" do
        expect {
          put("/category-experts/endorse/#{endorsee.username}.json", params: { categoryIds: [category1.id, category2.id] })
        }.to change { UserEndorsement.count }.by(2)
      end

      it "does not duplicate existing UserEndorsement records" do
        [category1, category2].each do |category|
          UserEndorsement.create(user: user, endorsed_user: endorsee, category: category)
        end

        expect {
          put("/category-experts/endorse/#{endorsee.username}.json", params: { categoryIds: [category1.id, category2.id] })
        }.to change { UserEndorsement.count }.by(0)
        expect(response.status).to eq(200)
      end
    end
  end
end
