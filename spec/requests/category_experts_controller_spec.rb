# frozen_string_literal: true

require "rails_helper"

describe CategoryExpertsController do
  fab!(:admin) { Fabricate(:admin) }
  fab!(:user) { Fabricate(:user) }
  fab!(:other_user) { Fabricate(:user) }
  fab!(:endorsee) { Fabricate(:user) }
  fab!(:group) { Fabricate(:group, users: [user]) }
  fab!(:other_group) { Fabricate(:group, users: [other_user]) }
  fab!(:category1) { fabricate_category_with_category_experts }
  fab!(:category2) { fabricate_category_with_category_experts }

  def fabricate_category_with_category_experts
    category = Fabricate(:category)
    enable_custom_fields_for(category)
    set_expert_group_for_category(category, "#{group.id}|#{other_group.id}")
    category.save
    category
  end

  def enable_custom_fields_for(category)
    category.custom_fields[CategoryExperts::CATEGORY_ACCEPTING_QUESTIONS] = true
    category.custom_fields[CategoryExperts::CATEGORY_ACCEPTING_ENDORSEMENTS] = true
  end

  def set_expert_group_for_category(category, group_ids)
    category.custom_fields[CategoryExperts::CATEGORY_EXPERT_GROUP_IDS] = group_ids
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

  describe "#endorsable_categories" do
    it "errors when the current user is not logged in" do
      get("/category-experts/endorsable-categories/#{endorsee.username}.json")
      expect(response.status).to eq(404)
    end

    context "logged in" do
      fab!(:private_category) { fabricate_category_with_category_experts }
      fab!(:private_group) { Fabricate(:group) }

      before do
        sign_in(user)
      end

      def expect_categories_in_response(response, categories)
        category_ids = response.parsed_body["categories"].map { |c| c["id"] }.sort
        expect(category_ids).to eq(categories.map(&:id).sort)
      end

      it "returns categories visible to the current user and endorsed user" do
        private_category.set_permissions({ private_group.id => :full })
        private_category.save

        # Endorsee and current user cannot see the new category
        get("/category-experts/endorsable-categories/#{endorsee.username}.json")
        expect_categories_in_response(response, [category1, category2])

        # Endorsee added. Current user still cannot see the new category
        private_group.add(endorsee)

        get("/category-experts/endorsable-categories/#{endorsee.username}.json")
        expect_categories_in_response(response, [category1, category2])

        # Both can now see the new category. It should be included
        private_group.add(user)

        get("/category-experts/endorsable-categories/#{endorsee.username}.json")
        expect_categories_in_response(response, [category1, category2, private_category])
      end
    end
  end

  describe "#approve_post" do
    fab!(:topic) { Fabricate(:topic, category: category1) }
    fab!(:first_post) { Fabricate(:post, topic: topic) }

    before do
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

        expect(topic.reload.custom_fields[CategoryExperts::TOPIC_EXPERT_POST_GROUP_NAMES]).to eq(group.name)
        expect(topic.custom_fields[CategoryExperts::TOPIC_NEEDS_EXPERT_POST_APPROVAL]).to eq(false)
      end

      it "adds the group names to the topic custom field when an approved post already exists" do
        CategoryExperts::PostHandler.new(post: topic.posts.last).mark_post_as_approved

        post = create_post(topic_id: topic.id, user: other_user)
        CategoryExperts::PostHandler.new(post: post).mark_post_for_approval

        post("/category-experts/approve.json", params: { post_id: post.id })

        expect(response.status).to eq(200)

        expect(topic.reload.custom_fields[CategoryExperts::TOPIC_EXPERT_POST_GROUP_NAMES]).to eq("#{group.name}|#{other_group.name}")
        expect(topic.custom_fields[CategoryExperts::TOPIC_NEEDS_EXPERT_POST_APPROVAL]).to eq(false)
      end
    end
  end

  describe "#unapprove_post" do
    fab!(:topic) { Fabricate(:topic, category: category1) }

    before do
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

        expect(topic.reload.custom_fields[CategoryExperts::TOPIC_EXPERT_POST_GROUP_NAMES]).to eq(nil)
        expect(topic.custom_fields[CategoryExperts::TOPIC_NEEDS_EXPERT_POST_APPROVAL]).to eq(true)
      end

      it "doesn't remove the group name from the topic custom field if another approved post exists" do
        post = create_post(topic_id: topic.id, user: user)
        CategoryExperts::PostHandler.new(post: post).mark_post_as_approved

        post2 = create_post(topic_id: topic.id, user: user)
        CategoryExperts::PostHandler.new(post: post2).mark_post_as_approved
        post("/category-experts/unapprove.json", params: { post_id: post2.id })

        expect(response.status).to eq(200)

        expect(topic.reload.custom_fields[CategoryExperts::TOPIC_EXPERT_POST_GROUP_NAMES]).to eq(group.name)
        expect(topic.custom_fields[CategoryExperts::TOPIC_NEEDS_EXPERT_POST_APPROVAL]).to eq(false)
      end
    end
  end

  describe "#retroactive_approval?" do
    fab!(:topic) { Fabricate(:topic, category: category1) }
    fab!(:random_user) { Fabricate(:user) }

    describe "non-staff user" do
      before do
        sign_in(user)
      end

      it "returns a 403" do
        post = create_post(topic_id: topic.id, user: user)
        get "/category-experts/retroactive-approval/#{post.id}.json"

        expect(response.status).to eq(403)
      end
    end

    describe "staff user signed in" do
      before do
        sign_in(admin)
      end

      it "return false when the category has no category expert groups" do
        post = create_post(topic_id: topic.id, user: random_user)
        CategoryCustomField.find_by(
          category_id: post.topic.category.id,
          name: CategoryExperts::CATEGORY_EXPERT_GROUP_IDS
        ).destroy
        get "/category-experts/retroactive-approval/#{post.id}.json"

        expect(response.status).to eq(200)
        expect(response.parsed_body["can_be_approved"]).to eq(false)
      end

      it "return false when the post is not by a category expert" do
        post = create_post(topic_id: topic.id, user: random_user)
        get "/category-experts/retroactive-approval/#{post.id}.json"

        expect(response.status).to eq(200)
        expect(response.parsed_body["can_be_approved"]).to eq(false)
      end

      it "returns false when the post is already marked as an expert post" do
        post = create_post(topic_id: topic.id, user: user)
        post.custom_fields[CategoryExperts::POST_APPROVED_GROUP_NAME] = "some-group"
        post.save

        get "/category-experts/retroactive-approval/#{post.id}.json"

        expect(response.status).to eq(200)
        expect(response.parsed_body["can_be_approved"]).to eq(false)
      end

      it "returns the expert group name when the post can be approved" do
        post = create_post(topic_id: topic.id, user: user)

        get "/category-experts/retroactive-approval/#{post.id}.json"

        expect(response.status).to eq(200)
        expect(response.parsed_body["can_be_approved"]).to eq(true)
      end
    end
  end
end
