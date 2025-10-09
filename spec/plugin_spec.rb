# frozen_string_literal: true

require "rails_helper"

RSpec.describe CategoryExperts do
  fab!(:admin)
  fab!(:expert) { Fabricate(:user, refresh_auto_groups: true) }

  fab!(:category)
  fab!(:group) { Fabricate(:group, users: [expert]) }
  fab!(:auto_tag, :tag)

  fab!(:original_topic) { Fabricate(:topic, category: category, tags: [auto_tag]) }
  fab!(:first_post) { Fabricate(:post, topic: original_topic, user: expert) }
  fab!(:second_post) { Fabricate(:post, topic: original_topic, user: expert) }

  fab!(:destination_topic) { Fabricate(:topic, category: category) }
  fab!(:destination_op) { Fabricate(:post, topic: destination_topic) }

  before do
    SiteSetting.enable_category_experts = true
    category.custom_fields[CategoryExperts::CATEGORY_EXPERT_GROUP_IDS] = "#{group.id}"
    category.custom_fields[CategoryExperts::CATEGORY_EXPERT_AUTO_TAG] = auto_tag.name
    category.save!

    CategoryExperts::PostHandler.new(post: second_post, user: expert).mark_post_as_approved
  end

  describe "Events" do
    describe "on 'post_moved'" do
      describe "Moving post to a topic without existing category expert post" do
        it "moves topic custom fields to new topic" do
          expect(
            original_topic.custom_fields[CategoryExperts::TOPIC_EXPERT_POST_GROUP_NAMES],
          ).to eq(group.name)
          expect(original_topic.custom_fields[CategoryExperts::TOPIC_FIRST_EXPERT_POST_ID]).to eq(
            second_post.post_number,
          )

          expect(
            destination_topic.custom_fields[CategoryExperts::TOPIC_EXPERT_POST_GROUP_NAMES],
          ).to be_blank
          expect(
            destination_topic.custom_fields[CategoryExperts::TOPIC_FIRST_EXPERT_POST_ID],
          ).to be_blank

          original_topic.move_posts(
            admin,
            [second_post.id],
            destination_topic_id: destination_topic.id,
          )

          original_topic.reload
          destination_topic.reload

          expect(
            original_topic.custom_fields[CategoryExperts::TOPIC_EXPERT_POST_GROUP_NAMES],
          ).to be_blank
          expect(
            original_topic.custom_fields[CategoryExperts::TOPIC_FIRST_EXPERT_POST_ID],
          ).to be_blank

          expect(
            destination_topic.custom_fields[CategoryExperts::TOPIC_EXPERT_POST_GROUP_NAMES],
          ).to eq(group.name)
          expect(
            destination_topic.custom_fields[CategoryExperts::TOPIC_FIRST_EXPERT_POST_ID],
          ).to eq(second_post.post_number)
        end

        context "with freeze_original for post move" do
          it "keeps existing custom fields on original topic and adds to new topic" do
            expect(
              original_topic.custom_fields[CategoryExperts::TOPIC_EXPERT_POST_GROUP_NAMES],
            ).to eq(group.name)
            expect(original_topic.custom_fields[CategoryExperts::TOPIC_FIRST_EXPERT_POST_ID]).to eq(
              second_post.post_number,
            )

            expect(
              destination_topic.custom_fields[CategoryExperts::TOPIC_EXPERT_POST_GROUP_NAMES],
            ).to be_blank
            expect(
              destination_topic.custom_fields[CategoryExperts::TOPIC_FIRST_EXPERT_POST_ID],
            ).to be_blank

            original_topic.move_posts(
              admin,
              [second_post.id],
              destination_topic_id: destination_topic.id,
              freeze_original: true,
            )

            original_topic.reload
            destination_topic.reload

            expect(
              original_topic.custom_fields[CategoryExperts::TOPIC_EXPERT_POST_GROUP_NAMES],
            ).to eq(group.name)
            expect(original_topic.custom_fields[CategoryExperts::TOPIC_FIRST_EXPERT_POST_ID]).to eq(
              second_post.post_number,
            )

            expect(
              destination_topic.custom_fields[CategoryExperts::TOPIC_EXPERT_POST_GROUP_NAMES],
            ).to eq(group.name)
            expect(
              destination_topic.custom_fields[CategoryExperts::TOPIC_FIRST_EXPERT_POST_ID],
            ).to eq(second_post.post_number)
          end
        end
      end

      context "when topics have existing category experts posts" do
        fab!(:other_group_expert) { Fabricate(:user, refresh_auto_groups: true) }
        fab!(:other_group) { Fabricate(:group, users: [other_group_expert]) }

        fab!(:original_topic_expert_post) do
          Fabricate(:post, topic: original_topic, user: other_group_expert)
        end
        fab!(:destination_topic_expert_post) do
          Fabricate(:post, topic: destination_topic, user: other_group_expert)
        end

        before do
          category.custom_fields[
            CategoryExperts::CATEGORY_EXPERT_GROUP_IDS
          ] = "#{group.id}|#{other_group.id}"
          category.save!

          CategoryExperts::PostHandler.new(
            post: original_topic_expert_post,
            user: other_group_expert,
          ).mark_post_as_approved
          CategoryExperts::PostHandler.new(
            post: destination_topic_expert_post,
            user: other_group_expert,
          ).mark_post_as_approved
        end

        it "Correctly adds and removes from topic custom fields without overriding existing fields" do
          expect(
            original_topic.custom_fields[CategoryExperts::TOPIC_EXPERT_POST_GROUP_NAMES],
          ).to eq("#{group.name}|#{other_group.name}")
          expect(original_topic.custom_fields[CategoryExperts::TOPIC_FIRST_EXPERT_POST_ID]).to eq(
            second_post.post_number,
          )

          expect(
            destination_topic.custom_fields[CategoryExperts::TOPIC_EXPERT_POST_GROUP_NAMES],
          ).to eq(other_group.name)
          expect(
            destination_topic.custom_fields[CategoryExperts::TOPIC_FIRST_EXPERT_POST_ID],
          ).to eq(destination_topic_expert_post.post_number)

          original_topic.move_posts(
            admin,
            [second_post.id],
            destination_topic_id: destination_topic.id,
          )

          original_topic.reload
          destination_topic.reload

          expect(
            original_topic.custom_fields[CategoryExperts::TOPIC_EXPERT_POST_GROUP_NAMES],
          ).to eq(other_group.name)

          expect(
            destination_topic.custom_fields[CategoryExperts::TOPIC_EXPERT_POST_GROUP_NAMES],
          ).to eq("#{other_group.name}|#{group.name}")
          expect(
            destination_topic.custom_fields[CategoryExperts::TOPIC_FIRST_EXPERT_POST_ID],
          ).to eq(destination_topic_expert_post.post_number)
        end

        context "with freeze_original for post move" do
          it "Correctly adds and removes from topic custom fields without overriding existing fields" do
            expect(
              original_topic.custom_fields[CategoryExperts::TOPIC_EXPERT_POST_GROUP_NAMES],
            ).to eq("#{group.name}|#{other_group.name}")
            expect(original_topic.custom_fields[CategoryExperts::TOPIC_FIRST_EXPERT_POST_ID]).to eq(
              second_post.post_number,
            )

            expect(
              destination_topic.custom_fields[CategoryExperts::TOPIC_EXPERT_POST_GROUP_NAMES],
            ).to eq(other_group.name)
            expect(
              destination_topic.custom_fields[CategoryExperts::TOPIC_FIRST_EXPERT_POST_ID],
            ).to eq(destination_topic_expert_post.post_number)

            original_topic.move_posts(
              admin,
              [second_post.id],
              destination_topic_id: destination_topic.id,
              freeze_original: true,
            )

            original_topic.reload
            destination_topic.reload

            expect(
              original_topic.custom_fields[CategoryExperts::TOPIC_EXPERT_POST_GROUP_NAMES],
            ).to eq("#{group.name}|#{other_group.name}")
            expect(original_topic.custom_fields[CategoryExperts::TOPIC_FIRST_EXPERT_POST_ID]).to eq(
              second_post.post_number,
            )

            expect(
              destination_topic.custom_fields[CategoryExperts::TOPIC_EXPERT_POST_GROUP_NAMES],
            ).to eq("#{other_group.name}|#{group.name}")
            expect(
              destination_topic.custom_fields[CategoryExperts::TOPIC_FIRST_EXPERT_POST_ID],
            ).to eq(destination_topic_expert_post.post_number)
          end
        end
      end
    end
  end
end
