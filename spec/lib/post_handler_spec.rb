# frozen_string_literal: true

require 'rails_helper'

describe CategoryExperts::PostHandler do
  fab!(:user) { Fabricate(:user) }
  fab!(:expert) { Fabricate(:user) }
  fab!(:category) { Fabricate(:category) }
  fab!(:group) { Fabricate(:group, users: [expert]) }
  fab!(:topic) { Fabricate(:topic, category: category) }

  before do
    SiteSetting.enable_category_experts
    SiteSetting.category_expert_suggestion_threshold
    category.custom_fields[CategoryExperts::CATEGORY_EXPERT_GROUP_IDS] = "#{group.id}|#{group.id + 1}"
    category.save

  end

  describe "SiteSetting.category_experts_posts_require_approval enabled" do
    before do
      SiteSetting.category_experts_posts_require_approval = true
    end

    describe "No existing approved expert posts" do
      it "marks the post as needing approval, as well as the topic" do
        result = NewPostManager.new(expert, raw: 'this is a new post', topic_id: topic.id).perform

        expect(result.post.custom_fields[CategoryExperts::POST_PENDING_EXPERT_APPROVAL]).to eq(true)
        expect(result.post.topic.custom_fields[CategoryExperts::TOPIC_NEEDS_EXPERT_POST_APPROVAL]).to eq(true)
      end
    end

    describe "With an existing approved expert post" do
      it "marks the post as needing approval, but not the topic" do
        post = create_post(topic_id: topic.id, user: expert)
        CategoryExperts::PostHandler.new(post: post, user: expert).mark_post_as_approved

        result = NewPostManager.new(expert, raw: 'this is a new post', topic_id: topic.id).perform

        expect(result.post.custom_fields[CategoryExperts::POST_PENDING_EXPERT_APPROVAL]).to eq(true)
        expect(result.post.topic.custom_fields[CategoryExperts::TOPIC_NEEDS_EXPERT_POST_APPROVAL]).to eq(false)
      end
    end
  end

  describe "SiteSetting.category_experts_posts_require_approval disabled" do
    before do
      SiteSetting.category_experts_posts_require_approval = false
    end

    it "marks posts as approved automatically" do
      result = NewPostManager.new(expert, raw: 'this is a new post', topic_id: topic.id).perform

      expect(result.post.custom_fields[CategoryExperts::POST_APPROVED_GROUP_NAME]).to eq(group.name)
      expect(result.post.topic.custom_fields[CategoryExperts::TOPIC_HAS_APPROVED_EXPERT_POST]).to eq(true)

      expect(result.post.custom_fields[CategoryExperts::POST_PENDING_EXPERT_APPROVAL]).to eq(false)
      expect(result.post.topic.custom_fields[CategoryExperts::TOPIC_NEEDS_EXPERT_POST_APPROVAL]).to eq(false)
    end
  end
end
