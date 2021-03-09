# frozen_string_literal: true

require "rails_helper"

describe CategoryExpertsController do
  fab!(:user) { Fabricate(:user) }
  fab!(:endorsee) { Fabricate(:user) }
  fab!(:group) { Fabricate(:group) }
  fab!(:category1) { fabricate_category_with_category_experts }
  fab!(:category2) { fabricate_category_with_category_experts }

  def fabricate_category_with_category_experts
    category = Fabricate(:category)
    enable_accepting_questions_for(category)
    set_expert_group_for_category(category, group)
    category.save
    category
  end

  def enable_accepting_questions_for(category)
    category.custom_fields[CategoryExperts::CATEGORY_ACCEPTING_ENDORSEMENTS] = true
  end

  def set_expert_group_for_category(category, group)
    category.custom_fields[CategoryExperts::CATEGORY_EXPERT_GROUP_IDS] = group.id.to_s
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

      it "creates new CategoryExpertEndorsement records for each category" do
        expect {
          put("/category-experts/endorse/#{endorsee.username}.json", params: { categoryIds: [category1.id, category2.id] })
        }.to change { CategoryExpertEndorsement.count }.by(2)
      end

      it "does not duplicate existing CategoryExpertEndorsement records" do
        [category1, category2].each do |category|
          CategoryExpertEndorsement.create(user: user, endorsed_user: endorsee, category: category)
        end

        expect {
          put("/category-experts/endorse/#{endorsee.username}.json", params: { categoryIds: [category1.id, category2.id] })
        }.to change { CategoryExpertEndorsement.count }.by(0)
        expect(response.status).to eq(200)
      end
    end
  end

  describe "#approve_post" do
    fab!(:topic) { Fabricate(:topic, category: category1) }
    fab!(:admin) { Fabricate(:admin) }

    before do
      group.add(user)
      create_post(topic_id: topic.id, user: user)
    end

    it "returns a 403 when regular user is signed in" do
      sign_in(user)

      SiteSetting.category_experts_posts_require_approval = true
      post("/category-experts/approve.json", params: { post_id: topic.posts.last.id })
      expect(response.status).to eq(403)
    end

    it "returns a 403 when `category_experts_post_require_approval` is false" do
      sign_in(admin)

      SiteSetting.category_experts_posts_require_approval = false
      post("/category-experts/approve.json", params: { post_id: topic.posts.last.id })
      expect(response.status).to eq(403)
    end

    context "Correctly configured" do
      before do
        sign_in(admin)
        SiteSetting.category_experts_posts_require_approval = true
      end

      it "approves the post and returns the expert group name" do
        last_post = topic.posts.last
        post("/category-experts/approve.json", params: { post_id: last_post.id })

        expect(response.status).to eq(200)

        expect(response.parsed_body["group_name"]).to eq(group.name)
        expect(last_post.custom_fields[CategoryExperts::POST_APPROVED_GROUP_NAME]).to eq(group.name)
        expect(last_post.custom_fields[CategoryExperts::POST_PENDING_EXPERT_APPROVAL]).to eq(false)
      end
    end
  end

  describe "#unapprove_post" do
    fab!(:topic) { Fabricate(:topic, category: category1) }
    fab!(:admin) { Fabricate(:admin) }

    before do
      group.add(user)
      create_post(topic_id: topic.id, user: user)
    end

    it "returns a 403 when regular user is signed in" do
      sign_in(user)

      SiteSetting.category_experts_posts_require_approval = true
      post("/category-experts/unapprove.json", params: { post_id: topic.posts.last.id })
      expect(response.status).to eq(403)
    end

    it "returns a 403 when `category_experts_post_require_approval` is false" do
      sign_in(admin)

      SiteSetting.category_experts_posts_require_approval = false
      post("/category-experts/unapprove.json", params: { post_id: topic.posts.last.id })
      expect(response.status).to eq(403)
    end

    context "Correctly configured" do
      before do
        sign_in(admin)
        SiteSetting.category_experts_posts_require_approval = true
      end

      it "unapproves the post and returns the expert group name" do
        last_post = topic.posts.last
        post("/category-experts/unapprove.json", params: { post_id: last_post.id })

        expect(response.status).to eq(200)

        expect(last_post.custom_fields[CategoryExperts::POST_APPROVED_GROUP_NAME]).to eq(nil)
        expect(last_post.custom_fields[CategoryExperts::POST_PENDING_EXPERT_APPROVAL]).to eq(true)
      end
    end
  end
end
