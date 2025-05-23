# frozen_string_literal: true

require "rails_helper"
require "webmock/rspec"

describe CategoryExperts::PostHandler do
  fab!(:user) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:admin)
  fab!(:expert) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:second_expert) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:category)
  fab!(:group) { Fabricate(:group, users: [expert]) }
  fab!(:second_group) { Fabricate(:group, users: [second_expert]) }
  fab!(:tag)
  fab!(:topic) { Fabricate(:topic, category: category, tags: [tag]) }
  fab!(:private_message_topic) do
    Fabricate(
      :private_message_topic,
      topic_allowed_users: [
        Fabricate.build(:topic_allowed_user, user: user),
        Fabricate.build(:topic_allowed_user, user: expert),
        Fabricate.build(:topic_allowed_user, user: second_expert),
      ],
    )
  end

  before do
    category.custom_fields[
      CategoryExperts::CATEGORY_EXPERT_GROUP_IDS
    ] = "#{group.id}|#{second_group.id}|#{group.id + 1}"
    category.save
  end

  describe "SiteSetting.category_experts_posts_require_approval enabled" do
    before do
      SiteSetting.category_experts_posts_require_approval = true
      SiteSetting.first_post_can_be_considered_expert_post = true
    end

    describe "No existing approved expert posts" do
      it "marks the post as needing approval, as well as the topic" do
        result = NewPostManager.new(expert, raw: "this is a new post", topic_id: topic.id).perform

        expect(result.post.custom_fields[CategoryExperts::POST_PENDING_EXPERT_APPROVAL]).to eq(true)
        expect(result.post.topic.custom_fields[CategoryExperts::TOPIC_FIRST_EXPERT_POST_ID]).to eq(
          nil,
        )
        expect(
          result.post.topic.custom_fields[CategoryExperts::TOPIC_NEEDS_EXPERT_POST_APPROVAL],
        ).to eq(result.post.post_number)
      end
    end

    it "topic without category like private message should not error" do
      expect {
        NewPostManager.new(
          expert,
          raw: "this is a new post",
          topic_id: private_message_topic.id,
        ).perform
      }.not_to raise_error
    end

    describe "With an existing approved expert post" do
      it "marks the post as needing approval, but not the topic" do
        existing_post = create_post(topic_id: topic.id, user: expert)
        CategoryExperts::PostHandler.new(post: existing_post).mark_post_as_approved

        result = NewPostManager.new(expert, raw: "this is a new post", topic_id: topic.id).perform

        expect(result.post.custom_fields[CategoryExperts::POST_PENDING_EXPERT_APPROVAL]).to eq(true)

        expect(result.post.topic.custom_fields[CategoryExperts::TOPIC_FIRST_EXPERT_POST_ID]).to eq(
          existing_post.post_number,
        )
        expect(
          result.post.topic.custom_fields[CategoryExperts::TOPIC_EXPERT_POST_GROUP_NAMES],
        ).to eq(group.name)
      end

      it "does nothing for non-regular posts" do
        expect {
          create_post(topic_id: topic.id, user: expert, post_type: Post.types[:small_action])
          create_post(topic_id: topic.id, user: expert, post_type: Post.types[:whisper])
          create_post(topic_id: topic.id, user: expert, post_type: Post.types[:moderator_action])
        }.not_to change {
          PostCustomField.where(
            name: [
              CategoryExperts::POST_APPROVED_GROUP_NAME,
              CategoryExperts::POST_PENDING_EXPERT_APPROVAL,
            ],
          ).count
        }
      end
    end

    describe "When post ownership is changed" do
      describe "from category expert to another expert" do
        it "updates the post approved group name" do
          post = create_post(topic_id: topic.id, user: expert)
          CategoryExperts::PostHandler.new(post: post).mark_post_as_approved

          expect(post.custom_fields[CategoryExperts::POST_APPROVED_GROUP_NAME]).to eq(group.name)

          PostOwnerChanger.new(
            post_ids: [post.id],
            topic_id: topic.id,
            new_owner: second_expert,
            acting_user: admin,
          ).change_owner!

          expect(post.reload.custom_fields[CategoryExperts::POST_APPROVED_GROUP_NAME]).to eq(
            second_group.name,
          )
        end
      end

      describe "from category expert to not an expert" do
        it "deletes the post approved group name" do
          post = create_post(topic_id: topic.id, user: expert)
          CategoryExperts::PostHandler.new(post: post).mark_post_as_approved

          expect(post.custom_fields[CategoryExperts::POST_APPROVED_GROUP_NAME]).to eq(group.name)

          PostOwnerChanger.new(
            post_ids: [post.id],
            topic_id: topic.id,
            new_owner: user,
            acting_user: admin,
          ).change_owner!

          expect(post.reload.custom_fields[CategoryExperts::POST_APPROVED_GROUP_NAME]).to eq(nil)
        end
      end

      describe "from not a category expert to an expert" do
        it "deletes the post approved group name" do
          post = create_post(topic_id: topic.id, user: user)
          expect(post.custom_fields[CategoryExperts::POST_APPROVED_GROUP_NAME]).to eq(nil)

          PostOwnerChanger.new(
            post_ids: [post.id],
            topic_id: topic.id,
            new_owner: expert,
            acting_user: admin,
          ).change_owner!

          expect(post.reload.custom_fields[CategoryExperts::POST_APPROVED_GROUP_NAME]).to eq(
            group.name,
          )
        end
      end
    end
  end

  describe "SiteSetting.category_experts_posts_require_approval disabled" do
    before do
      SiteSetting.category_experts_posts_require_approval = false
      SiteSetting.first_post_can_be_considered_expert_post = true
    end

    it "marks posts as approved automatically" do
      result = NewPostManager.new(expert, raw: "this is a new post", topic_id: topic.id).perform

      expect(result.post.custom_fields[CategoryExperts::POST_APPROVED_GROUP_NAME]).to eq(group.name)
      expect(result.post.custom_fields[CategoryExperts::POST_PENDING_EXPERT_APPROVAL]).to eq(false)
      expect(result.post.topic.custom_fields[CategoryExperts::TOPIC_EXPERT_POST_GROUP_NAMES]).to eq(
        group.name,
      )

      expect(result.post.topic.custom_fields[CategoryExperts::TOPIC_FIRST_EXPERT_POST_ID]).to eq(
        result.post.post_number,
      )
      expect(
        result.post.topic.custom_fields[CategoryExperts::TOPIC_NEEDS_EXPERT_POST_APPROVAL],
      ).to eq(nil)
    end

    it "correctly adds the expert group names to the topic custom fields" do
      post = create_post(topic_id: topic.id, user: expert)
      CategoryExperts::PostHandler.new(post: post).mark_post_as_approved
      expect(post.topic.custom_fields[CategoryExperts::TOPIC_EXPERT_POST_GROUP_NAMES]).to eq(
        group.name,
      )

      result =
        NewPostManager.new(second_expert, raw: "this is a new post", topic_id: topic.id).perform
      expect(result.post.topic.custom_fields[CategoryExperts::TOPIC_EXPERT_POST_GROUP_NAMES]).to eq(
        "#{group.name}|#{second_group.name}",
      )
    end

    describe "When post ownership is changed" do
      describe "from category expert to another expert" do
        it "updates the post approved group name" do
          post = create_post(topic_id: topic.id, user: expert)
          CategoryExperts::PostHandler.new(post: post).mark_post_as_approved

          expect(post.custom_fields[CategoryExperts::POST_APPROVED_GROUP_NAME]).to eq(group.name)

          PostOwnerChanger.new(
            post_ids: [post.id],
            topic_id: topic.id,
            new_owner: second_expert,
            acting_user: admin,
          ).change_owner!

          expect(post.reload.custom_fields[CategoryExperts::POST_APPROVED_GROUP_NAME]).to eq(
            second_group.name,
          )
        end
      end

      describe "from category expert to not an expert" do
        it "deletes the post approved group name" do
          post = create_post(topic_id: topic.id, user: expert)
          CategoryExperts::PostHandler.new(post: post).mark_post_as_approved

          expect(post.custom_fields[CategoryExperts::POST_APPROVED_GROUP_NAME]).to eq(group.name)

          PostOwnerChanger.new(
            post_ids: [post.id],
            topic_id: topic.id,
            new_owner: user,
            acting_user: admin,
          ).change_owner!

          expect(post.reload.custom_fields[CategoryExperts::POST_APPROVED_GROUP_NAME]).to eq(nil)
        end
      end

      describe "from not a category expert to an expert" do
        it "updates the post approved group name" do
          post = create_post(topic_id: topic.id, user: user)
          expect(post.custom_fields[CategoryExperts::POST_APPROVED_GROUP_NAME]).to eq(nil)

          PostOwnerChanger.new(
            post_ids: [post.id],
            topic_id: topic.id,
            new_owner: expert,
            acting_user: admin,
          ).change_owner!

          expect(post.reload.custom_fields[CategoryExperts::POST_APPROVED_GROUP_NAME]).to eq(
            group.name,
          )
        end
      end
    end
  end

  describe "Auto Tagging" do
    fab!(:auto_tag) { Fabricate(:tag) }

    before do
      category.custom_fields[CategoryExperts::CATEGORY_EXPERT_AUTO_TAG] = auto_tag.name
      category.save!
      SiteSetting.first_post_can_be_considered_expert_post = true
    end

    describe "Adding" do
      it "Doesn't error when the auto tag is already present on the topic" do
        post = create_post(topic_id: topic.id, user: user)
        PostRevisor.new(post).revise!(Discourse.system_user, tags: [auto_tag.name])

        expert_post = create_post(topic_id: topic.id, user: expert)
        CategoryExperts::PostHandler.new(post: expert_post).mark_post_as_approved
      end

      it "Adds the auto tag when topic doesn't already have it" do
        expert_post = create_post(topic_id: topic.id, user: expert)
        CategoryExperts::PostHandler.new(post: expert_post).mark_post_as_approved

        expect(topic.reload.tags.map(&:name)).to include(auto_tag.name)
      end
    end

    describe "Removing" do
      it "Removes the auto tag when the experts post is marked for approval" do
        post = create_post(topic_id: topic.id, user: expert)
        expect(topic.tags.map(&:name)).to include(auto_tag.name)

        # Have to reload, otherwise `PostRevisor` changes aren't picked up
        post.topic.reload
        CategoryExperts::PostHandler.new(post: post).mark_post_for_approval

        expect(topic.reload.tags.map(&:name)).not_to include(auto_tag.name)
      end

      it "Doesn't remove the auto tag when another category expert post is present" do
        post = create_post(topic_id: topic.id, user: expert)
        other_post = create_post(topic_id: topic.id, user: expert)
        expect(topic.tags.map(&:name)).to include(auto_tag.name)

        CategoryExperts::PostHandler.new(post: post).mark_post_for_approval

        expect(topic.reload.tags.map(&:name)).to include(auto_tag.name)
      end
    end
  end

  describe "SiteSetting.first_post_can_be_considered_expert_post false" do
    before do
      SiteSetting.category_experts_posts_require_approval = false
      SiteSetting.first_post_can_be_considered_expert_post = false
    end

    it "adds expert group names to the topic custom fields on second post, but not first post" do
      post = create_post(topic_id: topic.id, user: expert)
      CategoryExperts::PostHandler.new(post: post).mark_post_as_approved
      expect(post.topic.custom_fields[CategoryExperts::TOPIC_EXPERT_POST_GROUP_NAMES]).to eq(nil)

      result =
        NewPostManager.new(second_expert, raw: "this is a new post", topic_id: topic.id).perform
      expect(result.post.topic.custom_fields[CategoryExperts::TOPIC_EXPERT_POST_GROUP_NAMES]).to eq(
        second_group.name,
      )
    end

    it "adds expert group names to the post custom fields on second post, but not first post" do
      post = create_post(topic_id: topic.id, user: expert)
      CategoryExperts::PostHandler.new(post: post).mark_post_as_approved
      expect(post.custom_fields[CategoryExperts::POST_APPROVED_GROUP_NAME]).to eq(nil)

      result = NewPostManager.new(expert, raw: "this is a new post", topic_id: topic.id).perform
      expect(result.post.custom_fields[CategoryExperts::POST_APPROVED_GROUP_NAME]).to eq(group.name)
    end
  end

  describe "Webhook integration" do
    fab!(:webhook) { Fabricate(:outgoing_category_experts_web_hook) }
    fab!(:post) { create_post(topic_id: topic.id, user: expert) }

    before do
      SiteSetting.category_experts_posts_require_approval = true
      SiteSetting.first_post_can_be_considered_expert_post = true

      stub_request(:post, webhook.payload_url)
      Jobs.run_immediately!
    end

    it "sends a webhook event when a post is approved" do
      CategoryExperts::PostHandler.new(post: post).mark_post_as_approved(new_post: false)

      expect(WebMock).to have_requested(:post, webhook.payload_url)
        .with { |req|
          json = JSON.parse(req.body)
          req.headers["X-Discourse-Event"] == "category_experts_approved" &&
            json.dig("post", "id") == post.id
        }
        .once
    end

    it "sends a webhook event when a post is unapproved" do
      CategoryExperts::PostHandler.new(post: post).mark_post_for_approval(new_post: false)

      expect(WebMock).to have_requested(:post, webhook.payload_url)
        .with { |req|
          json = JSON.parse(req.body)
          req.headers["X-Discourse-Event"] == "category_experts_unapproved" &&
            json.dig("post", "id") == post.id
        }
        .once
    end

    it "does not send a webhook event when a post is created" do
      post1 = create_post(topic_id: topic.id, user: expert)

      expect(WebMock).not_to have_requested(:post, webhook.payload_url).with { |req|
        json = JSON.parse(req.body)
        req.headers["X-Discourse-Event"] == "category_experts_unapproved" &&
          json.dig("post", "id") == post1.id
      }
    end
  end
end
