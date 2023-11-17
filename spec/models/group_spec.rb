# frozen_string_literal: true

require "rails_helper"

describe Group do
  fab!(:user) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:category) { Fabricate(:category) }
  fab!(:group) { Fabricate(:group) }
  fab!(:topic) { Fabricate(:topic, category: category) }

  before do
    SiteSetting.approve_past_posts_on_becoming_category_expert = true
    Jobs.run_immediately!
    category.custom_fields[CategoryExperts::CATEGORY_EXPERT_GROUP_IDS] = group.id
    category.save
  end

  describe "Adding user to expert group" do
    describe "SiteSetting.category_experts_posts_require_approval = true" do
      before { SiteSetting.category_experts_posts_require_approval = true }

      it "marks past posts as approved" do
        post = create_post(topic_id: topic.id, user: user)
        group.add(user)
        expect(topic.custom_fields[CategoryExperts::TOPIC_NEEDS_EXPERT_POST_APPROVAL]).to eq(
          post.post_number,
        )
        expect(topic.first_post.custom_fields[CategoryExperts::POST_PENDING_EXPERT_APPROVAL]).to eq(
          true,
        )
      end
    end

    describe "SiteSetting.category_experts_posts_require_approval = false" do
      before do
        SiteSetting.category_experts_posts_require_approval = false
        SiteSetting.first_post_can_be_considered_expert_post = true
      end

      it "marks past posts as requiring approval" do
        post = create_post(topic_id: topic.id, user: user)
        group.add(user)
        expect(topic.reload.custom_fields[CategoryExperts::TOPIC_EXPERT_POST_GROUP_NAMES]).to eq(
          group.name,
        )
        expect(topic.first_post.custom_fields[CategoryExperts::POST_APPROVED_GROUP_NAME]).to eq(
          group.name,
        )
      end
    end
  end

  describe "Removing expert from group" do
    fab!(:other_expert) { Fabricate(:user, refresh_auto_groups: true) }

    before do
      group.add(user)
      group.add(other_expert)

      post = create_post(topic_id: topic.id, user: user)
      CategoryExperts::PostHandler.new(post: post).mark_post_as_approved

      NewPostManager.new(user, raw: "this is a new post", topic_id: topic.id).perform
    end

    it "removes past post custom fields when the expert is removed" do
      post = topic.posts.last
      expect(post.custom_fields[CategoryExperts::POST_APPROVED_GROUP_NAME]).to eq(group.name)

      group.remove(user)
      expect(post.reload.custom_fields[CategoryExperts::POST_APPROVED_GROUP_NAME]).to eq(nil)
    end

    it "does not remove topic custom fields if another expert has replied" do
      post = create_post(topic_id: topic.id, user: other_expert)
      CategoryExperts::PostHandler.new(post: post).mark_post_as_approved

      group.remove(user)
      expect(topic.reload.custom_fields[CategoryExperts::TOPIC_EXPERT_POST_GROUP_NAMES]).to eq(
        group.name,
      )
    end
  end
end
