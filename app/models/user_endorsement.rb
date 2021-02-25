# frozen_string_literal: true

class UserEndorsement < ActiveRecord::Base
  belongs_to :user
  belongs_to :endorsed_user, class_name: "User"
  belongs_to :category

  validate :not_endorsing_self

  private

  def not_endorsing_self
    errors.add(:user_id, "cannot endorse self") if user == endorsed_user
  end
end
