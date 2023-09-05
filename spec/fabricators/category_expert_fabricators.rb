# frozen_string_literal: true

Fabricator(:category_expert_endorsement) do
  user
  category
  endorsed_user { Fabricate(:user) }
end

Fabricator(:reviewable_category_expert_suggestion) do
  reviewable_by_moderator false
  type "ReviewableCategoryExpertSuggestion"
  created_by { Fabricate(:user) }
  topic
  target_type "CategoryExpertEndorsement"
  target { Fabricate(:category_expert_endorsement) }
end
