# frozen_string_literal: true

require "rails_helper"

describe Jobs::RemoveExpertPostPropertiesFromFirstPosts do
  fab!(:user) { Fabricate(:user) }
  fab!(:expert) { Fabricate(:user) }
  fab!(:category) { Fabricate(:category) }
  fab!(:group) { Fabricate(:group, users: [expert]) }
  fab!(:topic) { Fabricate(:topic, category: category)}

  before do
    category.custom_fields[
      CategoryExperts::CATEGORY_EXPERT_GROUP_IDS
    ] = "#{group.id}"
    category.save
    Jobs.run_immediately!
    SiteSetting.category_experts_posts_require_approval = false
    SiteSetting.first_post_can_be_considered_expert_post = true
  end

  it "removes expert post properties from first posts" do

    result = NewPostManager.new(expert, raw: "this is a new post", topic_id: topic.id).perform
    # pp result.post
    # pp result.post.custom_fields
    # pp result.post.topic
    # pp result.post.topic.custom_fields
    expect(result.post.custom_fields[CategoryExperts::POST_APPROVED_GROUP_NAME]).to eq(group.name)
    expect(result.post.topic.custom_fields[CategoryExperts::TOPIC_FIRST_EXPERT_POST_ID]).to eq(1)
    expect(result.post.topic.custom_fields[CategoryExperts::TOPIC_EXPERT_POST_GROUP_NAMES]).to eq(group.name)

    Jobs::RemoveExpertPostPropertiesFromFirstPosts.new.execute
    post = Post.first
    expect(post.raw).to eq "this is a new post"
    expect(post.custom_fields[CategoryExperts::POST_APPROVED_GROUP_NAME]).to eq(nil)
    expect(post.topic.custom_fields[CategoryExperts::TOPIC_FIRST_EXPERT_POST_ID]).to eq(nil)
    expect(post.topic.custom_fields[CategoryExperts::TOPIC_EXPERT_POST_GROUP_NAMES]).to eq(nil)

  end
end
