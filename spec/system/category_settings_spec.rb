# frozen_string_literal: true

describe "Category Experts Category Settings" do
  fab!(:admin)
  fab!(:category)
  fab!(:group)

  let(:category_page) { PageObjects::Pages::Category.new }
  let(:form) { PageObjects::Components::FormKit.new(".form-kit") }
  let(:banner) { PageObjects::Components::AdminChangesBanner.new }
  let(:toasts) { PageObjects::Components::Toasts.new }

  before do
    SiteSetting.enable_category_experts = true
    SiteSetting.enable_simplified_category_creation = true
    sign_in(admin)
  end

  it "renders the category experts section with FormKit fields" do
    category_page.visit_settings(category)

    expect(page).to have_css(".category-experts-settings")
    expect(page).to have_css(".category-experts-settings .group-chooser")
  end

  it "can configure category expert groups and save" do
    category_page.visit_settings(category)

    group_chooser =
      PageObjects::Components::SelectKit.new(".category-experts-settings .group-chooser")
    group_chooser.expand
    group_chooser.select_row_by_value(group.id)
    banner.click_save

    expect(toasts).to have_success(I18n.t("js.saved"))
    expect(category.reload.custom_fields["category_expert_group_ids"]).to eq(group.id.to_s)
  end
end
