# frozen_string_literal: true

class ChangeBooleanCustomFieldsToInts < ActiveRecord::Migration[6.1]
  def up
    set_topic_first_approved_post_ids
    set_topic_needs_approval_to_int
  end

  def set_topic_needs_approval_to_int
    topic_needs_approval_custom_field_ids = execute("SELECT topic_id FROM topic_custom_fields WHERE name='category_expert_topic_post_needs_approval' AND value = 't'").values.flatten

    topic_needs_approval_custom_field_ids.each do |topic_id|
      post_number = execute(<<~SQL
        SELECT p.post_number
        FROM posts AS p
        INNER JOIN post_custom_fields AS pcf ON pcf.post_id = p.id AND p.topic_id = #{topic_id}
        WHERE pcf.name='category_expert_post_pending' AND value = 't'
        ORDER BY pcf.id ASC
        LIMIT 1
                        SQL
                       )

      if post_number.count > 0
        # We have a custom field, now update the 't' to be the post_id.
        execute(<<~SQL
                UPDATE topic_custom_fields
                SET value = #{post_number.getvalue(0, 0)}
                WHERE topic_id = #{topic_id}
                AND name = 'category_expert_topic_post_needs_approval'
                SQL
               )
      end

    end
    # Now set all 'f' values to integer 0
    execute(<<~SQL
              UPDATE topic_custom_fields
              SET value = 0
              WHERE value = 'f'
              AND name = 'category_expert_topic_post_needs_approval'
            SQL
           )
  end

  def set_topic_first_approved_post_ids
    topic_approved_custom_field_ids = execute("SELECT topic_id FROM topic_custom_fields WHERE name='category_expert_topic_approved_group_names' AND value IS NOT NULL")

    topic_approved_custom_field_ids.values.flatten.each do |topic_id|
      post_number = execute(<<~SQL
        SELECT p.post_number
        FROM posts AS p
        INNER JOIN post_custom_fields AS pcf ON pcf.post_id = p.id AND p.topic_id = #{topic_id}
        WHERE pcf.name='category_expert_post' AND value IS NOT NULL
        ORDER BY pcf.id ASC
        LIMIT 1
                        SQL
                       )
      if (post_number.count > 0)
        now = Time.now

        # Create a new topic custom field with the first expert post id
        execute(<<~SQL
          INSERT INTO topic_custom_fields(topic_id, name, value, created_at, updated_at)
          VALUES(#{topic_id}, 'category_expert_first_expert_post_id', #{post_number.getvalue(0, 0)}, '#{now}', '#{now}')
                SQL
               )
      end
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
