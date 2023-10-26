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
    category.custom_fields[CategoryExperts::CATEGORY_ACCEPTING_QUESTIONS] = "true"
    category.custom_fields[CategoryExperts::CATEGORY_ACCEPTING_ENDORSEMENTS] = "true"
  end

  def set_expert_group_for_category(category, group_ids)
    category.custom_fields[CategoryExperts::CATEGORY_EXPERT_GROUP_IDS] = group_ids
  end

  describe "#endorse" do
    it "errors when the current user is not logged in" do
      put(
        "/category-experts/endorse/#{endorsee.username}.json",
        params: {
          categoryIds: [category1.id],
        },
      )
      expect(response.status).to eq(404)
    end

    context "when logged in" do
      before { sign_in(user) }

      it "errors when no category ids are present" do
        put("/category-experts/endorse/#{endorsee.username}.json", params: { categoryIds: [] })
        expect(response.status).to eq(400)
      end

      it "errors when the category isn't accepting endorsements" do
        category = Fabricate(:category)
        put(
          "/category-experts/endorse/#{endorsee.username}.json",
          params: {
            categoryIds: [category.id],
          },
        )
        expect(response.status).to eq(400)
      end

      it "creates new CategoryExpertEndorsement records for each category" do
        expect {
          put(
            "/category-experts/endorse/#{endorsee.username}.json",
            params: {
              categoryIds: [category1.id, category2.id],
            },
          )
        }.to change { CategoryExpertEndorsement.count }.by(2)
      end

      it "does not duplicate existing CategoryExpertEndorsement records" do
        [category1, category2].each do |category|
          CategoryExpertEndorsement.create(user: user, endorsed_user: endorsee, category: category)
        end

        expect {
          put(
            "/category-experts/endorse/#{endorsee.username}.json",
            params: {
              categoryIds: [category1.id, category2.id],
            },
          )
        }.not_to change { CategoryExpertEndorsement.count }
        expect(response.status).to eq(200)
      end
    end

    describe "rate limiting" do
      before do
        sign_in(user)
        SiteSetting.max_category_expert_endorsements_per_day = 1
        RateLimiter.enable
      end

      use_redis_snapshotting

      it "returns a 429 when rate limits are hit for tl0" do
        freeze_time
        user.update(trust_level: TrustLevel[0])

        put(
          "/category-experts/endorse/#{endorsee.username}.json",
          params: {
            categoryIds: [category1.id],
          },
        )
        expect(response.status).to eq(200)
        put(
          "/category-experts/endorse/#{endorsee.username}.json",
          params: {
            categoryIds: [category2.id],
          },
        )
        expect(response.status).to eq(429)
      end

      it "returns a 429 when rate limits are hit for tl2" do
        freeze_time
        user.update(trust_level: TrustLevel[2])
        SiteSetting.tl2_additional_category_expert_endorsements_per_day_multiplier = 2

        put(
          "/category-experts/endorse/#{endorsee.username}.json",
          params: {
            categoryIds: [category1.id],
          },
        )
        expect(response.status).to eq(200)
        put(
          "/category-experts/endorse/#{endorsee.username}.json",
          params: {
            categoryIds: [category2.id],
          },
        )
        expect(response.status).to eq(200)
        put(
          "/category-experts/endorse/#{endorsee.username}.json",
          params: {
            categoryIds: [category2.id],
          },
        )
        expect(response.status).to eq(429)
      end
    end
  end

  describe "#endorsable_categories" do
    it "errors when the current user is not logged in" do
      get("/category-experts/endorsable-categories/#{endorsee.username}.json")
      expect(response.status).to eq(404)
    end

    context "when logged in" do
      fab!(:private_category) { fabricate_category_with_category_experts }
      fab!(:private_group) { Fabricate(:group) }
      fab!(:category3) { fabricate_category_with_category_experts }

      before { sign_in(user) }

      def expect_categories_in_response(response, categories)
        category_ids = response.parsed_body["categories"].map { |c| c["id"] }.sort
        expect(category_ids).to eq(categories.map(&:id).sort)
      end

      it "returns categories visible to the current user and endorsed user" do
        private_category.set_permissions({ private_group.id => :full })
        private_category.save

        category3.custom_fields[CategoryExperts::CATEGORY_ACCEPTING_ENDORSEMENTS] = "false"
        category3.save

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

    before { create_post(topic_id: topic.id, user: user) }

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

    context "when correctly configured" do
      before do
        sign_in(admin)
        SiteSetting.category_experts_posts_require_approval = true
        SiteSetting.first_post_can_be_considered_expert_post = true
      end

      it "approves the post and returns the expert group name" do
        last_post = topic.posts.last
        post("/category-experts/approve.json", params: { post_id: last_post.id })

        expect(response.status).to eq(200)

        expect(response.parsed_body["group_name"]).to eq(group.name)
        expect(last_post.custom_fields[CategoryExperts::POST_APPROVED_GROUP_NAME]).to eq(group.name)
        expect(last_post.custom_fields[CategoryExperts::POST_PENDING_EXPERT_APPROVAL]).to eq(false)

        expect(topic.reload.custom_fields[CategoryExperts::TOPIC_EXPERT_POST_GROUP_NAMES]).to eq(
          group.name,
        )
        expect(topic.custom_fields[CategoryExperts::TOPIC_NEEDS_EXPERT_POST_APPROVAL]).to eq(nil)
      end

      it "adds the group names to the topic custom field when an approved post already exists" do
        CategoryExperts::PostHandler.new(post: topic.first_post).mark_post_as_approved

        post = create_post(topic_id: topic.id, user: other_user)
        CategoryExperts::PostHandler.new(post: post).mark_post_for_approval

        post("/category-experts/approve.json", params: { post_id: post.id })

        expect(response.status).to eq(200)

        expect(topic.reload.custom_fields[CategoryExperts::TOPIC_EXPERT_POST_GROUP_NAMES]).to eq(
          "#{group.name}|#{other_group.name}",
        )
        expect(topic.custom_fields[CategoryExperts::TOPIC_FIRST_EXPERT_POST_ID]).to eq(
          topic.first_post.post_number,
        )

        expect(topic.custom_fields[CategoryExperts::TOPIC_NEEDS_EXPERT_POST_APPROVAL]).to eq(nil)
      end
    end
  end

  describe "#unapprove_post" do
    fab!(:topic) { Fabricate(:topic, category: category1) }

    before { create_post(topic_id: topic.id, user: user) }

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

    context "when correctly configured" do
      before do
        sign_in(admin)
        SiteSetting.category_experts_posts_require_approval = true
        SiteSetting.first_post_can_be_considered_expert_post = true
      end

      it "unapproves the post and returns the expert group name" do
        last_post = topic.posts.last
        post("/category-experts/unapprove.json", params: { post_id: last_post.id })

        expect(response.status).to eq(200)

        expect(last_post.custom_fields[CategoryExperts::POST_APPROVED_GROUP_NAME]).to eq(nil)
        expect(last_post.custom_fields[CategoryExperts::POST_PENDING_EXPERT_APPROVAL]).to eq(true)

        expect(topic.reload.custom_fields[CategoryExperts::TOPIC_EXPERT_POST_GROUP_NAMES]).to eq(
          nil,
        )
        expect(topic.custom_fields[CategoryExperts::TOPIC_NEEDS_EXPERT_POST_APPROVAL]).to eq(
          last_post.post_number,
        )
      end

      it "doesn't remove the group name from the topic custom field if another approved post exists" do
        CategoryExperts::PostHandler.new(post: topic.first_post).mark_post_as_approved

        post = create_post(topic_id: topic.id, user: user)
        CategoryExperts::PostHandler.new(post: post).mark_post_as_approved

        post("/category-experts/unapprove.json", params: { post_id: post.id })

        expect(response.status).to eq(200)

        expect(topic.reload.custom_fields[CategoryExperts::TOPIC_EXPERT_POST_GROUP_NAMES]).to eq(
          group.name,
        )
        expect(topic.custom_fields[CategoryExperts::TOPIC_NEEDS_EXPERT_POST_APPROVAL]).to eq(nil)
      end
    end
  end
end
