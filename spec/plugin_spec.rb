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

    describe "on 'post_edited' with category change" do
      fab!(:category_b, :category)
      fab!(:group_b, :group)

      before do
        category_b.custom_fields[CategoryExperts::CATEGORY_EXPERT_GROUP_IDS] = "#{group_b.id}"
        category_b.save!
      end

      context "when topic is moved from category with experts to category without experts" do
        it "clears all expert custom fields from posts and topic" do
          expect(
            original_topic.custom_fields[CategoryExperts::TOPIC_EXPERT_POST_GROUP_NAMES],
          ).to eq(group.name)
          expect(original_topic.custom_fields[CategoryExperts::TOPIC_FIRST_EXPERT_POST_ID]).to eq(
            second_post.post_number,
          )
          expect(second_post.custom_fields[CategoryExperts::POST_APPROVED_GROUP_NAME]).to eq(
            group.name,
          )

          category_without_experts = Fabricate(:category)

          PostRevisor.new(original_topic.first_post).revise!(
            admin,
            category_id: category_without_experts.id,
          )

          original_topic.reload
          second_post.reload

          expect(
            original_topic.custom_fields[CategoryExperts::TOPIC_EXPERT_POST_GROUP_NAMES],
          ).to be_blank
          expect(
            original_topic.custom_fields[CategoryExperts::TOPIC_FIRST_EXPERT_POST_ID],
          ).to be_blank
          expect(second_post.custom_fields[CategoryExperts::POST_APPROVED_GROUP_NAME]).to be_blank
        end
      end

      context "when topic is moved from one category with experts to another with different experts" do
        it "updates expert custom fields appropriately when user is not expert in new category" do
          expect(
            original_topic.custom_fields[CategoryExperts::TOPIC_EXPERT_POST_GROUP_NAMES],
          ).to eq(group.name)
          expect(second_post.custom_fields[CategoryExperts::POST_APPROVED_GROUP_NAME]).to eq(
            group.name,
          )

          PostRevisor.new(original_topic.first_post).revise!(admin, category_id: category_b.id)

          original_topic.reload
          second_post.reload

          expect(
            original_topic.custom_fields[CategoryExperts::TOPIC_EXPERT_POST_GROUP_NAMES],
          ).to be_blank
          expect(second_post.custom_fields[CategoryExperts::POST_APPROVED_GROUP_NAME]).to be_blank
        end

        it "updates expert group name when user is expert in both categories" do
          group_b.add(expert)

          expect(
            original_topic.custom_fields[CategoryExperts::TOPIC_EXPERT_POST_GROUP_NAMES],
          ).to eq(group.name)
          expect(second_post.custom_fields[CategoryExperts::POST_APPROVED_GROUP_NAME]).to eq(
            group.name,
          )

          PostRevisor.new(original_topic.first_post).revise!(admin, category_id: category_b.id)

          original_topic.reload
          second_post.reload

          expect(
            original_topic.custom_fields[CategoryExperts::TOPIC_EXPERT_POST_GROUP_NAMES],
          ).to eq(group_b.name)
          expect(second_post.custom_fields[CategoryExperts::POST_APPROVED_GROUP_NAME]).to eq(
            group_b.name,
          )
        end

        context "with multiple expert posts from different users" do
          fab!(:expert_2) { Fabricate(:user, refresh_auto_groups: true) }
          fab!(:third_post) { Fabricate(:post, topic: original_topic, user: expert_2) }

          before do
            group.add(expert_2)
            CategoryExperts::PostHandler.new(post: third_post, user: expert_2).mark_post_as_approved
          end

          it "only keeps expert status for users who are experts in new category" do
            group_b.add(expert)

            expect(
              original_topic.custom_fields[CategoryExperts::TOPIC_EXPERT_POST_GROUP_NAMES],
            ).to eq(group.name)
            expect(second_post.custom_fields[CategoryExperts::POST_APPROVED_GROUP_NAME]).to eq(
              group.name,
            )
            expect(third_post.custom_fields[CategoryExperts::POST_APPROVED_GROUP_NAME]).to eq(
              group.name,
            )

            PostRevisor.new(original_topic.first_post).revise!(admin, category_id: category_b.id)

            original_topic.reload
            second_post.reload
            third_post.reload

            expect(
              original_topic.custom_fields[CategoryExperts::TOPIC_EXPERT_POST_GROUP_NAMES],
            ).to eq(group_b.name)
            expect(second_post.custom_fields[CategoryExperts::POST_APPROVED_GROUP_NAME]).to eq(
              group_b.name,
            )
            expect(third_post.custom_fields[CategoryExperts::POST_APPROVED_GROUP_NAME]).to be_blank
          end
        end
      end

      context "when topic has auto-tag" do
        fab!(:auto_tag_b, :tag)

        before do
          SiteSetting.tagging_enabled = true
          category_b.custom_fields[CategoryExperts::CATEGORY_EXPERT_AUTO_TAG] = auto_tag_b.name
          category_b.save!
        end

        it "removes old auto-tag and adds new auto-tag when category changes" do
          expect(original_topic.tags.map(&:name)).to include(auto_tag.name)
          expect(original_topic.tags.map(&:name)).not_to include(auto_tag_b.name)

          PostRevisor.new(original_topic.first_post).revise!(admin, category_id: category_b.id)

          original_topic.reload

          expect(original_topic.tags.map(&:name)).not_to include(auto_tag.name)
          expect(original_topic.tags.map(&:name)).to include(auto_tag_b.name)
        end
      end
    end
  end
end
