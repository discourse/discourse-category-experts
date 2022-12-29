# frozen_string_literal: true

class CreateCategoryExpertEndorsements < ActiveRecord::Migration[6.0]
  def change
    create_table :category_expert_endorsements do |t|
      t.integer :user_id, null: false
      t.integer :endorsed_user_id, null: false
      t.integer :category_id, null: false
    end

    add_index :category_expert_endorsements,
              %i[user_id endorsed_user_id category_id],
              unique: true,
              name: "category_expert_endorsements_index" # Default name was too long.
  end
end
