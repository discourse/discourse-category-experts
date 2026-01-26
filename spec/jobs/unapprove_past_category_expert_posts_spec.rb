# frozen_string_literal: true

describe Jobs::UnapprovePastCategoryExpertPosts do
  fab!(:user)
  fab!(:group) { Fabricate(:group, users: [user]) }
  fab!(:category) { fabricate_category_with_category_experts }
  fab!(:topic) { Fabricate(:topic, category: category) }
  fab!(:p1) { create_post(user: user, topic: topic) }
  fab!(:p2) { create_post(user: user, topic: topic) }
  fab!(:p3) { create_post(user: user, topic: topic) }
  fab!(:p4) { create_post(user: user, topic: topic) }

  def fabricate_category_with_category_experts
    category = Fabricate(:category)
    category.custom_fields[CategoryExperts::CATEGORY_EXPERT_GROUP_IDS] = group.id
    category.save
    category
  end

  before do
    SiteSetting.enable_category_experts = true
    Jobs.run_immediately!

    topic.custom_fields[CategoryExperts::TOPIC_EXPERT_POST_GROUP_NAMES] = group.name
    topic.save!

    # Create 2 approved posts and 2 pending approval
    p1.custom_fields[CategoryExperts::POST_APPROVED_GROUP_NAME] = group.name
    p1.save!

    p2.custom_fields[CategoryExperts::POST_APPROVED_GROUP_NAME] = group.name
    p2.save!

    p3.custom_fields[CategoryExperts::POST_PENDING_EXPERT_APPROVAL] = "t"
    p3.save!

    p4.custom_fields[CategoryExperts::POST_PENDING_EXPERT_APPROVAL] = "t"
    p4.save!
  end

  describe "Site setting approve_past_posts_on_becoming_category_expert is false" do
    it "only removed pending approval" do
      SiteSetting.approve_past_posts_on_becoming_category_expert = false
      group.remove(user)

      expect(p1.reload.custom_fields[CategoryExperts::POST_APPROVED_GROUP_NAME]).to eq(group.name)
      expect(p2.reload.custom_fields[CategoryExperts::POST_APPROVED_GROUP_NAME]).to eq(group.name)
      expect(p3.reload.custom_fields[CategoryExperts::POST_PENDING_EXPERT_APPROVAL]).to eq(nil)
      expect(p4.reload.custom_fields[CategoryExperts::POST_PENDING_EXPERT_APPROVAL]).to eq(nil)
      expect(topic.reload.custom_fields[CategoryExperts::TOPIC_EXPERT_POST_GROUP_NAMES]).to eq(
        group.name,
      )
    end
  end

  describe "Site setting approve_past_posts_on_becoming_category_expert is true" do
    it "only removed pending approval" do
      SiteSetting.approve_past_posts_on_becoming_category_expert = true
      group.remove(user)

      expect(p1.reload.custom_fields[CategoryExperts::POST_APPROVED_GROUP_NAME]).to eq(nil)
      expect(p2.reload.custom_fields[CategoryExperts::POST_APPROVED_GROUP_NAME]).to eq(nil)
      expect(p3.reload.custom_fields[CategoryExperts::POST_PENDING_EXPERT_APPROVAL]).to eq(nil)
      expect(p4.reload.custom_fields[CategoryExperts::POST_PENDING_EXPERT_APPROVAL]).to eq(nil)
      expect(topic.reload.custom_fields[CategoryExperts::TOPIC_EXPERT_POST_GROUP_NAMES]).to eq(nil)
    end
  end
end
