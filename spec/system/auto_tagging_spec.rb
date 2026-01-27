# frozen_string_literal: true

describe "Category Experts Auto Tagging", type: :system do
  fab!(:admin)
  fab!(:expert) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:category)
  fab!(:group) { Fabricate(:group, users: [expert]) }
  fab!(:auto_tag) { Fabricate(:tag, name: "expert-answered") }
  fab!(:topic) { Fabricate(:topic, category: category) }
  fab!(:post) { Fabricate(:post, topic: topic) }

  let(:category_page) { PageObjects::Pages::Category.new }
  let(:topic_page) { PageObjects::Pages::Topic.new }
  let(:composer) { PageObjects::Components::Composer.new }
  let(:tag_chooser) do
    PageObjects::Components::SelectKit.new(".category-experts-auto-tagging .tag-chooser")
  end

  before do
    SiteSetting.enable_category_experts = true
    SiteSetting.tagging_enabled = true
    SiteSetting.category_experts_posts_require_approval = false
  end

  describe "configuring auto-tag in category settings" do
    it "allows selecting/unselecting an auto-tag and saves it correctly" do
      category_page.visit_settings(category)

      expect(page).to have_css(".category-experts-auto-tagging", wait: 10)

      tag_chooser.expand
      tag_chooser.search(auto_tag.name)
      tag_chooser.select_row_by_name(auto_tag.name)

      category_page.save_settings

      expect(tag_chooser.value).to eq(auto_tag.name)

      tag_chooser.unselect_by_name(auto_tag.name)
      category_page.save_settings

      expect(tag_chooser.value).to eq("")
    end
  end

  describe "auto-tagging topics when expert posts" do
    before do
      category.custom_fields[CategoryExperts::CATEGORY_EXPERT_GROUP_IDS] = group.id.to_s
      category.custom_fields[CategoryExperts::CATEGORY_EXPERT_AUTO_TAG] = auto_tag.name
      category.save!
      sign_in(expert)
    end

    it "adds the auto-tag when an expert posts a reply" do
      expect(topic.reload.tags).not_to include(auto_tag)

      topic_page.visit_topic(topic)
      topic_page.click_reply_button
      composer.fill_content("This is an expert reply to the topic")
      composer.submit

      expect(topic_page).to have_post_number(2)
      expect(topic.reload.tags).to include(auto_tag)
    end
  end
end
