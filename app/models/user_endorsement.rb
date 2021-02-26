# frozen_string_literal: true

class UserEndorsement < ActiveRecord::Base
  belongs_to :user
  belongs_to :endorsed_user, class_name: "User"
  belongs_to :category

  validate :not_endorsing_self

  after_commit :create_reviewable, on: :create

  private

  def create_reviewable
    endorsements_for_category = UserEndorsement.where(endorsed_user: endorsed_user, category: category).count
    if endorsements_for_category == SiteSetting.category_expert_suggestion_threshold
      ReviewableCategoryExpertSuggestion.needs_review!(
        created_by: user,
        target: self
      )
    end
  end

  def not_endorsing_self
    errors.add(:user_id, "cannot endorse self") if user == endorsed_user
  end
end
