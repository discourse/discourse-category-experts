# frozen_string_literal: true

class AddTimestampsToCategoryExpertsEndorsements < ActiveRecord::Migration[6.0]
  def change
    add_timestamps :category_expert_endorsements, null: false, default: -> { 'NOW()' }
  end
end
