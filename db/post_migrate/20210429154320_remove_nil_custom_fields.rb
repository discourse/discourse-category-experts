# frozen_string_literal: true

class RemoveNilCustomFields < ActiveRecord::Migration[6.1]
  def up
    execute <<~SQL
      DELETE FROM post_custom_fields
      WHERE name = 'category_expert_post' AND value IS NULL
    SQL

    execute <<~SQL
      DELETE FROM post_custom_fields
      WHERE name = 'category_expert_post_pending' AND value IS NULL
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
