class CreateUserEndorsements < ActiveRecord::Migration[6.0]
  def change
    create_table :user_endorsements do |t|
      t.integer :user_id, null: false
      t.integer :endorsed_user_id, null: false
      t.integer :category_id, null: false
    end

    add_index :user_endorsements, [:user_id]
    add_index :user_endorsements, [:endorsed_user_id]
    add_index :user_endorsements, [:category_id]
  end
end
