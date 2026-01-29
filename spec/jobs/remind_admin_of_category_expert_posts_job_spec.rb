# frozen_string_literal: true

describe CategoryExperts::RemindAdminOfCategoryExpertsPostsJob do
  subject(:execute) { described_class.new.execute }

  fab!(:expert, :user)
  fab!(:group) { Fabricate(:group, users: [expert]) }
  fab!(:category) { fabricate_category_with_category_experts }

  def fabricate_category_with_category_experts
    category = Fabricate(:category)
    category.custom_fields[CategoryExperts::CATEGORY_ACCEPTING_QUESTIONS] = true
    category.custom_fields[CategoryExperts::CATEGORY_EXPERT_GROUP_IDS] = group.id
    category.save
    category
  end

  before do
    4.times do |n|
      # Create 4 questions, 1 with no expert posts, 2 with unapproved expert posts, and 1 with an approved expert post
      topic = Fabricate(:topic, category: category)
      topic.custom_fields[CategoryExperts::TOPIC_IS_CATEGORY_EXPERT_QUESTION] = true
      if n == 0 || n == 1
        topic.custom_fields[CategoryExperts::TOPIC_NEEDS_EXPERT_POST_APPROVAL] = true
      elsif n == 2
        topic.custom_fields[CategoryExperts::TOPIC_EXPERT_POST_GROUP_NAMES] = group.id
      end
      topic.save
    end
  end

  describe "with site setting enabled" do
    before { SiteSetting.send_category_experts_reminder_pms = true }

    xit "sends a PM to staff and moderators with the proper topic count" do
      expect { execute }.to change { Topic.count }.by(1)

      pm = Topic.where(archetype: Archetype.private_message).last
      expect(pm.first_post.raw.start_with?("There are [2 category expert questions]")).to eq(true)
    end
  end

  describe "with site setting disabled" do
    before { SiteSetting.send_category_experts_reminder_pms = false }

    xit "does nothing" do
      expect { execute }.not_to change { Topic.count }
    end
  end
end
