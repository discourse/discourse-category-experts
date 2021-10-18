# frozen_string_literal: true

require 'rails_helper'

describe CategoryExperts::PostHandler do
  fab!(:user) { Fabricate(:user) }
  fab!(:expert) { Fabricate(:user) }
  fab!(:second_expert) { Fabricate(:user) }
  fab!(:category) { Fabricate(:category) }
  fab!(:group) { Fabricate(:group, users: [expert]) }
  fab!(:second_group) { Fabricate(:group, users: [second_expert]) }
  fab!(:topic) { Fabricate(:topic, category: category) }
  fab!(:private_message_topic) { Fabricate(:private_message_topic, topic_allowed_users: [
    Fabricate.build(:topic_allowed_user, user: user),
    Fabricate.build(:topic_allowed_user, user: expert),
    Fabricate.build(:topic_allowed_user, user: second_expert),
  ]) }

  before do
    category.custom_fields[CategoryExperts::CATEGORY_EXPERT_GROUP_IDS] = "#{group.id}|#{second_group.id}|#{group.id + 1}"
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
        expect(result.post.topic.custom_fields[CategoryExperts::TOPIC_FIRST_EXPERT_POST_ID]).to eq(nil)
        expect(result.post.topic.custom_fields[CategoryExperts::TOPIC_NEEDS_EXPERT_POST_APPROVAL]).to eq(result.post.post_number)
      end
    end

    it "topic without category like private message should not error" do
      expect { NewPostManager.new(expert, raw: 'this is a new post', topic_id: private_message_topic.id).perform }.not_to raise_error
    end

    describe "With an existing approved expert post" do
      it "marks the post as needing approval, but not the topic" do
        existing_post = create_post(topic_id: topic.id, user: expert)
        CategoryExperts::PostHandler.new(post: existing_post).mark_post_as_approved

        result = NewPostManager.new(expert, raw: 'this is a new post', topic_id: topic.id).perform

        expect(result.post.custom_fields[CategoryExperts::POST_PENDING_EXPERT_APPROVAL]).to eq(true)

        expect(result.post.topic.custom_fields[CategoryExperts::TOPIC_FIRST_EXPERT_POST_ID]).to eq(existing_post.post_number)
        expect(result.post.topic.custom_fields[CategoryExperts::TOPIC_EXPERT_POST_GROUP_NAMES]).to eq(group.name)
      end

      it "does nothing for non-regular posts" do
        expect {
          create_post(topic_id: topic.id, user: expert, post_type: Post.types[:small_action])
          create_post(topic_id: topic.id, user: expert, post_type: Post.types[:whisper])
          create_post(topic_id: topic.id, user: expert, post_type: Post.types[:moderator_action])
        }.to change {
          PostCustomField.where(name: [
            CategoryExperts::POST_APPROVED_GROUP_NAME,
            CategoryExperts::POST_PENDING_EXPERT_APPROVAL
          ]).count
        }.by(0)
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
      expect(result.post.custom_fields[CategoryExperts::POST_PENDING_EXPERT_APPROVAL]).to eq(false)
      expect(result.post.topic.custom_fields[CategoryExperts::TOPIC_EXPERT_POST_GROUP_NAMES]).to eq(group.name)

      expect(result.post.topic.custom_fields[CategoryExperts::TOPIC_FIRST_EXPERT_POST_ID]).to eq(result.post.post_number)
      expect(result.post.topic.custom_fields[CategoryExperts::TOPIC_NEEDS_EXPERT_POST_APPROVAL]).to eq(nil)
    end

    it "correctly adds the expert group names to the topic custom fields" do
      post = create_post(topic_id: topic.id, user: expert)
        CategoryExperts::PostHandler.new(post: post).mark_post_as_approved
        expect(post.topic.custom_fields[CategoryExperts::TOPIC_EXPERT_POST_GROUP_NAMES]).to eq(group.name)

        result = NewPostManager.new(second_expert, raw: 'this is a new post', topic_id: topic.id).perform
        expect(result.post.topic.custom_fields[CategoryExperts::TOPIC_EXPERT_POST_GROUP_NAMES]).to eq("#{group.name}|#{second_group.name}")
    end
  end
end
