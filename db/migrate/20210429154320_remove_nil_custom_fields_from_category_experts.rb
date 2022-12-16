# frozen_string_literal: true

class RemoveNilCustomFieldsFromCategoryExperts < ActiveRecord::Migration[6.0]
  def up
    execute <<~SQL
      DELETE FROM post_custom_fields
      WHERE name = 'category_expert_post' AND value IS NULL
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
