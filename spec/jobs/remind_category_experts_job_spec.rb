# frozen_string_literal: true

require 'rails_helper'

describe CategoryExperts::RemindCategoryExpertsJob do
  fab!(:user) { Fabricate(:user) }
  fab!(:expert1) { Fabricate(:user) }
  fab!(:expert2) { Fabricate(:user) }

  fab!(:group1) { Fabricate(:group, users: [expert1, expert2]) }
  fab!(:group2) { Fabricate(:group, users: [expert1]) }

  fab!(:category1) { fabricate_category_with_category_experts([group1, group2]) }
  fab!(:category2) { fabricate_category_with_category_experts([group2]) }

  def fabricate_category_with_category_experts(groups)
    category = Fabricate(:category)
    category.custom_fields[CategoryExperts::CATEGORY_ACCEPTING_QUESTIONS] = true
    category.custom_fields[CategoryExperts::CATEGORY_EXPERT_GROUP_IDS] = groups.map(&:id).join("|")
    category.save
    category
  end

  before do
    3.times do |n|
      # Create 2 questions, and 1 unapproved answered question for category 1
      topic = Fabricate(:topic, category: category1)
      topic.custom_fields[CategoryExperts::TOPIC_IS_CATEGORY_EXPERT_QUESTION] = true
      if n == 0
        topic.custom_fields[CategoryExperts::TOPIC_NEEDS_EXPERT_POST_APPROVAL] = true
      end
      topic.save
    end

    2.times do |n|
      # Create 1 question, and 1 approved answered question for category 2
      topic = Fabricate(:topic, category: category2)
      topic.custom_fields[CategoryExperts::TOPIC_IS_CATEGORY_EXPERT_QUESTION] = true
      if n == 0
        topic.custom_fields[CategoryExperts::TOPIC_EXPERT_POST_GROUP_NAMES] = true
      end
      topic.save
    end
  end

  it "Sends out the correct PM to each category expert" do
    SiteSetting.send_category_experts_reminder_pms = true

    expect {
      subject.execute()
    }.to change { Topic.count }.by (2) # Sent a PM to each expert

    # Expert 1 should get 2 rows, 1 for each category
    expert1_message = expert1.topics_allowed.where(archetype: Archetype.private_message).last
    split_raw = expert1_message.first_post.raw.split("\n")

    expect(split_raw.count).to eq(2)
    expect(split_raw.first.include?("There are [2 unanswered")).to eq(true)
    expect(split_raw.second.include?("There are [1 unanswered")).to eq(true)

    # Expert 2 should only get 1 row
    expert2_message = expert2.topics_allowed.where(archetype: Archetype.private_message).last
    split_raw = expert2_message.first_post.raw.split("\n")

    expect(split_raw.count).to eq(1)
    expect(split_raw.first.include?("There are [2 unanswered")).to eq(true)
  end

  it "Does nothing if the site setting is disabled" do
    SiteSetting.send_category_experts_reminder_pms = false
    expect {
      subject.execute()
    }.to change { Topic.count }.by (0)
  end
end
