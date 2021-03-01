class CreateCategoryExpertEndorsements < ActiveRecord::Migration[6.0]
  def change
    create_table :category_expert_endorsements do |t|
      t.integer :user_id, null: false
      t.integer :endorsed_user_id, null: false
      t.integer :category_id, null: false
    end

    add_index :category_expert_endorsements, [:user_id]
    add_index :category_expert_endorsements, [:endorsed_user_id]
    add_index :category_expert_endorsements, [:category_id]
  end
end
