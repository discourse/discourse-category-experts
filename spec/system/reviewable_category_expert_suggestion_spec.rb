# frozen_string_literal: true

describe "Reviewables - Category expert suggestion", type: :system, js: true do
  fab!(:current_user) { Fabricate(:user) }
  fab!(:other_user) { Fabricate(:user) }
  fab!(:category)
  fab!(:group)
  let(:modal) { PageObjects::Modals::Base.new }

  before do
    SiteSetting.enable_category_experts = true
    SiteSetting.category_expert_suggestion_threshold = 1

    sign_in(current_user)
    category.custom_fields[CategoryExperts::CATEGORY_EXPERT_GROUP_IDS] = group.id.to_s
    category.custom_fields[CategoryExperts::CATEGORY_ACCEPTING_ENDORSEMENTS] = true
    category.save!
  end

  it "can endorse users as category experts to place them in the review queue" do
    visit "/u/#{other_user.username_lower}"

    find(".category-expert-endorse-btn").click
    find(".category-endorsement-checkbox").click
    modal.click_primary_button

    expect(page).to have_content(I18n.t("js.category_experts.existing_endorsements", count: 1))

    reviewable = ReviewableCategoryExpertSuggestion.find_by(created_by: current_user)
    expect(reviewable.status).to eq("pending")
    expect(reviewable.target_type).to eq("CategoryExpertEndorsement")
  end

  context "as an admin reviewing endorsements" do
    fab!(:current_user) { Fabricate(:admin) }

    skip "can approve an endorsement" do
      endorsement =
        Fabricate(:category_expert_endorsement, category: category, endorsed_user: other_user)
      visit "/review"

      reviewable = ReviewableCategoryExpertSuggestion.find_by(target: endorsement)
      expect(page).to have_css(".reviewable-item[data-reviewable-id=\"#{reviewable.id}\"]")

      find(".reviewable-action", text: /Approve/).click
      expect(modal).to have_content(group.name)
      find("#tap_tile_#{group.id}").click
      expect(page).to have_content(I18n.t("js.review.none"), wait: 5)
      expect(reviewable.reload.status).to eq("approved")
    end

    it "can reject an endorsement" do
      endorsement =
        Fabricate(:category_expert_endorsement, category: category, endorsed_user: other_user)
      visit "/review"

      reviewable = ReviewableCategoryExpertSuggestion.find_by(target: endorsement)
      expect(page).to have_css(".reviewable-item[data-reviewable-id=\"#{reviewable.id}\"]")

      find(".reviewable-action", text: /Ignore/).click
      expect(page).to have_content(I18n.t("js.review.none"), wait: 5)
      expect(reviewable.reload.status).to eq("rejected")
    end
  end
end
