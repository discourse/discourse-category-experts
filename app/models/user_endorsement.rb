# frozen_string_literal: true

class UserEndorsement < ActiveRecord::Base
  belongs_to :user
  belongs_to :endorsed_user, class_name: "User"
  belongs_to :category
end
