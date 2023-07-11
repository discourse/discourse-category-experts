# frozen_string_literal: true

require "rails_helper"

describe Jobs::CorrectHistoricalCategoryExpertPosts do
  fab!(:user1) { Fabricate(:user) }
  fab!(:user2) { Fabricate(:user) }
  fab!(:group1) { Fabricate(:group, users: [user1]) }
  fab!(:group2) { Fabricate(:group, users: [user1, user2]) }
  fab!(:category1) { Fabricate(:category) }
  fab!(:category2) { Fabricate(:category) }
  # Create a few topics
  fab!(:off_topic) { Fabricate(:topic) }
  fab!(:topic1) { Fabricate(:topic, category: category1) }
  fab!(:topic2) { Fabricate(:topic, category: category2) }
  # No custom fields needed
  fab!(:p1) { create_post(user: user1, topic: off_topic) }
  fab!(:p2) { create_post(user: user2, topic: off_topic) }

  # custom fields for only p3, not p4.
  fab!(:p3) { create_post(user: user1, topic: topic1) }
  fab!(:p4) { create_post(user: user2, topic: topic1) }

  # custom fields for both p5 and p6
  fab!(:p5) { create_post(user: user1, topic: topic2) }
  fab!(:p6) { create_post(user: user2, topic: topic2) }

  before do
    SiteSetting.enable_category_experts = true
    SiteSetting.category_experts_posts_require_approval = false
    SiteSetting.approve_past_posts_on_becoming_category_expert = true
    SiteSetting.first_post_can_be_considered_expert_post = true
    Jobs.run_immediately!
  end

  it "correctly applies custom fields" do
    category1.custom_fields[CategoryExperts::CATEGORY_EXPERT_GROUP_IDS] = group1.id
    category1.save
    category2.custom_fields[CategoryExperts::CATEGORY_EXPERT_GROUP_IDS] = group2.id
    category2.save

    Jobs::CorrectHistoricalCategoryExpertPosts.new.execute
    # Topic fields
    expect(off_topic.custom_fields[CategoryExperts::TOPIC_EXPERT_POST_GROUP_NAMES]).to eq(nil)
    expect(topic1.custom_fields[CategoryExperts::TOPIC_EXPERT_POST_GROUP_NAMES]).to eq(group1.name)
    expect(topic2.custom_fields[CategoryExperts::TOPIC_EXPERT_POST_GROUP_NAMES]).to eq(group2.name)

    # Post fields
    expect(p1.custom_fields[CategoryExperts::POST_APPROVED_GROUP_NAME]).to eq(nil)
    expect(p2.custom_fields[CategoryExperts::POST_APPROVED_GROUP_NAME]).to eq(nil)
    expect(p3.custom_fields[CategoryExperts::POST_APPROVED_GROUP_NAME]).to eq(group1.name)
    expect(p4.custom_fields[CategoryExperts::POST_APPROVED_GROUP_NAME]).to eq(nil)
    expect(p5.custom_fields[CategoryExperts::POST_APPROVED_GROUP_NAME]).to eq(group2.name)
    expect(p6.custom_fields[CategoryExperts::POST_APPROVED_GROUP_NAME]).to eq(group2.name)
  end
end
