# frozen_string_literal: true

class CategoryExpertEndorsement < ActiveRecord::Base
  belongs_to :user
  belongs_to :endorsed_user, class_name: "User"
  belongs_to :category

  validate :not_endorsing_self

  after_commit :create_reviewable, on: :create

  private

  def create_reviewable
    endorsements =
      CategoryExpertEndorsement.includes(:user).where(
        endorsed_user: endorsed_user,
        category: category,
      )

    if endorsements.count == SiteSetting.category_expert_suggestion_threshold
      reviewable = ReviewableCategoryExpertSuggestion.needs_review!(created_by: user, target: self)
      endorsements.each do |endorsement|
        reviewable.add_score(
          endorsement.user,
          ReviewableScore.types[:needs_approval],
          force_review: true,
        )
      end
    end
  end

  def not_endorsing_self
    errors.add(:user_id, "cannot endorse self") if user == endorsed_user
  end
end

# == Schema Information
#
# Table name: category_expert_endorsements
#
#  id               :bigint           not null, primary key
#  user_id          :integer          not null
#  endorsed_user_id :integer          not null
#  category_id      :integer          not null
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#
# Indexes
#
#  category_expert_endorsements_index  (user_id,endorsed_user_id,category_id) UNIQUE
#
