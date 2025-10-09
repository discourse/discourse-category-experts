# frozen_string_literal: true

# name: discourse-category-experts
# about: Allows users to endorse each other as experts in specific categories.
# meta_topic_id: 190814
# version: 0.0.1
# authors: Mark VanLandingham
# url: https://github.com/discourse/discourse-category-experts

register_asset "stylesheets/common.scss"

enabled_site_setting :enable_category_experts

after_initialize do
  WebHookEventType.const_set(:CATEGORY_EXPERTS_APPROVED, 30_478)
  WebHookEventType.const_set(:CATEGORY_EXPERTS_UNAPPROVED, 30_479)

  SeedFu.fixture_paths << Rails
    .root
    .join("plugins", "discourse-category-experts", "db", "fixtures")
    .to_s

  module ::CategoryExperts
    PLUGIN_NAME = "discourse-category-experts".freeze
    CATEGORY_EXPERT_GROUP_IDS = "category_expert_group_ids"
    CATEGORY_EXPERT_AUTO_TAG = "category_expert_auto_tag"
    CATEGORY_ACCEPTING_ENDORSEMENTS = "category_accepting_endorsements"
    CATEGORY_ACCEPTING_QUESTIONS = "category_accepting_questions"
    CATEGORY_BADGE_ID = "category_experts_badge_id"
    POST_APPROVED_GROUP_NAME = "category_expert_post"
    POST_PENDING_EXPERT_APPROVAL = "category_expert_post_pending"
    TOPIC_EXPERT_POST_GROUP_NAMES = "category_expert_topic_approved_group_names"
    TOPIC_FIRST_EXPERT_POST_ID = "category_expert_first_expert_post_id"
    TOPIC_NEEDS_EXPERT_POST_APPROVAL = "category_expert_topic_post_needs_approval"
    TOPIC_IS_CATEGORY_EXPERT_QUESTION = "category_expert_topic_is_question"

    class Engine < ::Rails::Engine
      engine_name CategoryExperts::PLUGIN_NAME
      isolate_namespace CategoryExperts
    end
  end

  %w[
    ../app/controllers/category_experts_controller
    ../app/models/category_expert_endorsement
    ../app/models/reviewable_category_expert_suggestion
    ../app/serializers/reviewable_category_expert_suggestion_serializer
    ../app/jobs/regular/approve_past_category_expert_posts
    ../app/jobs/regular/correct_historical_category_expert_posts
    ../app/jobs/regular/remove_expert_post_properties_from_first_posts
    ../app/jobs/regular/unapprove_past_category_expert_posts
    ../app/jobs/scheduled/remind_admin_of_category_experts_posts_job
    ../app/jobs/scheduled/remind_category_experts_job
    ../lib/category_experts/post_handler
    ../lib/category_experts/endorsement_rate_limiter
    ../lib/category_experts/user_extension
    ../lib/category_experts/outgoing_web_hook_extension
  ].each { |path| require File.expand_path(path, __FILE__) }

  register_reviewable_type ReviewableCategoryExpertSuggestion

  add_permitted_reviewable_param(:reviewable_category_expert_suggestion, :group_id)

  add_custom_reviewable_filter(
    [
      :endorsed_username,
      Proc.new do |results, value|
        user_id = User.find_by_username(value)&.id
        return results if user_id.blank?
        results.joins(
          "INNER JOIN category_expert_endorsements ON category_expert_endorsements.id = target_id",
        ).where("category_expert_endorsements.endorsed_user_id = ?", user_id)
      end,
    ],
  )

  register_post_custom_field_type(CategoryExperts::POST_APPROVED_GROUP_NAME, :string)
  register_post_custom_field_type(CategoryExperts::POST_PENDING_EXPERT_APPROVAL, :boolean)
  topic_view_post_custom_fields_allowlister do
    [CategoryExperts::POST_APPROVED_GROUP_NAME, CategoryExperts::POST_PENDING_EXPERT_APPROVAL]
  end

  register_topic_custom_field_type(CategoryExperts::TOPIC_EXPERT_POST_GROUP_NAMES, :string)
  register_topic_custom_field_type(CategoryExperts::TOPIC_FIRST_EXPERT_POST_ID, :integer)
  register_topic_custom_field_type(CategoryExperts::TOPIC_NEEDS_EXPERT_POST_APPROVAL, :integer)
  register_topic_custom_field_type(CategoryExperts::TOPIC_IS_CATEGORY_EXPERT_QUESTION, :boolean)

  [
    CategoryExperts::TOPIC_EXPERT_POST_GROUP_NAMES,
    CategoryExperts::TOPIC_NEEDS_EXPERT_POST_APPROVAL,
    CategoryExperts::TOPIC_IS_CATEGORY_EXPERT_QUESTION,
    CategoryExperts::TOPIC_FIRST_EXPERT_POST_ID,
  ].each do |field|
    add_preloaded_topic_list_custom_field(field)
    Search.preloaded_topic_custom_fields << field
  end

  register_category_custom_field_type(CategoryExperts::CATEGORY_EXPERT_GROUP_IDS, :string)
  register_category_custom_field_type(CategoryExperts::CATEGORY_EXPERT_AUTO_TAG, :string)
  register_category_custom_field_type(CategoryExperts::CATEGORY_ACCEPTING_ENDORSEMENTS, :boolean)
  register_category_custom_field_type(CategoryExperts::CATEGORY_ACCEPTING_QUESTIONS, :boolean)
  register_category_custom_field_type(CategoryExperts::CATEGORY_BADGE_ID, :string)

  Site.preloaded_category_custom_fields << CategoryExperts::CATEGORY_EXPERT_GROUP_IDS
  Site.preloaded_category_custom_fields << CategoryExperts::CATEGORY_EXPERT_AUTO_TAG
  Site.preloaded_category_custom_fields << CategoryExperts::CATEGORY_ACCEPTING_ENDORSEMENTS
  Site.preloaded_category_custom_fields << CategoryExperts::CATEGORY_ACCEPTING_QUESTIONS
  Site.preloaded_category_custom_fields << CategoryExperts::CATEGORY_BADGE_ID

  add_permitted_post_update_param(
    :is_category_expert_question,
  ) do |post, is_category_expert_question|
    if post.is_first_post?
      topic = post.topic
      topic.custom_fields[
        CategoryExperts::TOPIC_IS_CATEGORY_EXPERT_QUESTION
      ] = is_category_expert_question.to_s == "true"
      topic.save!
    end
  end

  reloadable_patch do
    User.prepend(CategoryExperts::UserExtension)
    WebHook.prepend(CategoryExperts::OutgoingWebHookExtension)
  end

  add_to_class(:user, :given_category_expert_endorsements_for) do |user|
    given_category_expert_endorsements.where(endorsed_user_id: user.id)
  end

  add_to_class(:user, :expert_group_ids_for_category) do |category|
    unsplit_expert_group_ids =
      category.custom_fields&.[](CategoryExperts::CATEGORY_EXPERT_GROUP_IDS)
    return [] if unsplit_expert_group_ids.nil?

    unsplit_expert_group_ids.split("|").map(&:to_i) & group_ids
  end

  add_to_serializer(:current_user, :expert_for_category_ids) do
    user_group_ids = object.group_ids
    return [] if user_group_ids.empty?

    CategoryCustomField
      .where(name: CategoryExperts::CATEGORY_EXPERT_GROUP_IDS)
      .select do |custom_field|
        (custom_field.value.split("|").map(&:to_i) & user_group_ids).count > 0
      end
      .map(&:category_id)
  end

  add_to_class(:category, :accepting_category_expert_endorsements?) do
    custom_fields[CategoryExperts::CATEGORY_EXPERT_GROUP_IDS] &&
      custom_fields[CategoryExperts::CATEGORY_ACCEPTING_ENDORSEMENTS]
  end

  add_to_class(:category, :accepting_category_expert_questions?) do
    custom_fields[CategoryExperts::CATEGORY_EXPERT_GROUP_IDS] &&
      custom_fields[CategoryExperts::CATEGORY_ACCEPTING_QUESTIONS]
  end

  add_to_serializer(:user_card, :category_expert_endorsements) do
    return unless SiteSetting.enable_category_experts
    return if !scope.current_user || scope.current_user == object

    scope.current_user.given_category_expert_endorsements_for(object)
  end

  add_to_serializer(:post, :category_expert_approved_group) do
    post_custom_fields[CategoryExperts::POST_APPROVED_GROUP_NAME]
  end

  add_to_serializer(:post, :needs_category_expert_approval) do
    post_custom_fields[CategoryExperts::POST_PENDING_EXPERT_APPROVAL]
  end

  add_to_serializer(:post, :can_manage_category_expert_posts) { scope.is_staff? }

  add_to_class(:topic, :is_category_expert_question?) do
    custom_fields[CategoryExperts::TOPIC_IS_CATEGORY_EXPERT_QUESTION] &&
      category.custom_fields[CategoryExperts::CATEGORY_EXPERT_GROUP_IDS].present?
  end

  reloadable_patch do
    %i[topic_list_item search_topic_list_item].each do |serializer|
      add_to_serializer(
        serializer,
        :needs_category_expert_post_approval,
        include_condition: -> do
          scope.is_staff? &&
            object.custom_fields[CategoryExperts::TOPIC_NEEDS_EXPERT_POST_APPROVAL] &&
            object.custom_fields[CategoryExperts::TOPIC_NEEDS_EXPERT_POST_APPROVAL] > 0
        end,
      ) { true }

      add_to_serializer(
        serializer,
        :expert_post_group_names,
        include_condition: -> do
          object.custom_fields[CategoryExperts::TOPIC_EXPERT_POST_GROUP_NAMES].present?
        end,
      ) { object.custom_fields[CategoryExperts::TOPIC_EXPERT_POST_GROUP_NAMES].split("|") }

      add_to_serializer(
        serializer,
        :first_expert_post_id,
        include_condition: -> { include_expert_post_group_names? },
      ) { object.custom_fields[CategoryExperts::TOPIC_FIRST_EXPERT_POST_ID] }

      add_to_serializer(
        serializer,
        :is_category_expert_question,
        include_condition: -> { object.is_category_expert_question? },
      ) { true }
    end
  end

  add_to_serializer(:topic_view, :is_category_expert_question) do
    object.topic.is_category_expert_question?
  end

  add_to_serializer(
    :topic_view,
    :expert_post_group_names,
    include_condition: -> do
      object.topic.custom_fields[CategoryExperts::TOPIC_EXPERT_POST_GROUP_NAMES].present?
    end,
  ) { object.topic.custom_fields[CategoryExperts::TOPIC_EXPERT_POST_GROUP_NAMES].split("|") }

  add_to_serializer(
    :topic_view,
    :expert_post_group_count,
    include_condition: -> do
      object.topic.custom_fields[CategoryExperts::TOPIC_EXPERT_POST_GROUP_NAMES].present?
    end,
  ) do
    object.topic.custom_fields[CategoryExperts::TOPIC_EXPERT_POST_GROUP_NAMES]
      .split("|")
      .inject({}) do |hash, group_name|
        hash[group_name] = object
          .topic
          .posts
          .joins("INNER JOIN post_custom_fields ON posts.id = post_custom_fields.post_id")
          .where(post_custom_fields: { name: "category_expert_post", value: group_name })
          .count
        hash
      end
  end

  add_permitted_post_create_param(:is_category_expert_question)

  if Search.respond_to? :preloaded_topic_custom_fields
    Search.preloaded_topic_custom_fields << CategoryExperts::TOPIC_EXPERT_POST_GROUP_NAMES
    Search.preloaded_topic_custom_fields << CategoryExperts::TOPIC_IS_CATEGORY_EXPERT_QUESTION
  end

  register_search_advanced_filter(/with:category_expert_response/) do |posts|
    posts.where(
      "topics.id IN (
        SELECT tc.topic_id
        FROM topic_custom_fields tc
        WHERE tc.name = '#{CategoryExperts::TOPIC_EXPERT_POST_GROUP_NAMES}' AND
              tc.value <> ''
        )",
    )
  end

  register_search_advanced_filter(/is:category_expert_question/) { |posts| posts.where(<<~SQL) }
      topics.id IN (
        SELECT topics.id
        FROM topics
        INNER JOIN topic_custom_fields tc ON topics.id = tc.topic_id
        WHERE tc.name = '#{CategoryExperts::TOPIC_IS_CATEGORY_EXPERT_QUESTION}' AND
              tc.value = 't'
        EXCEPT
        SELECT topics.id
        FROM topics
        INNER JOIN topic_custom_fields otc ON topics.id = otc.topic_id
        WHERE otc.name = '#{CategoryExperts::TOPIC_EXPERT_POST_GROUP_NAMES}' AND
              otc.value <> '' AND
              otc.value IS NOT NULL
      )
    SQL

  register_search_advanced_filter(/without:category_expert_post/) { |posts| posts.where(<<~SQL) }
      topics.id IN (
        SELECT topics.id
        FROM topics
        EXCEPT
        SELECT topics.id
        FROM topics
        INNER JOIN topic_custom_fields tc ON topics.id = tc.topic_id
        WHERE (tc.name = '#{CategoryExperts::TOPIC_NEEDS_EXPERT_POST_APPROVAL}' AND
              tc.value <> '0')
        OR (tc.name = '#{CategoryExperts::TOPIC_EXPERT_POST_GROUP_NAMES}' AND
              tc.value <> '' AND
              tc.value IS NOT NULL)
        )
    SQL

  register_search_advanced_filter(/with:unapproved_ce_post/) { |posts| posts.where(<<~SQL) }
      topics.id IN (
        SELECT topics.id
        FROM topics
        INNER JOIN topic_custom_fields tc ON topics.id = tc.topic_id
        WHERE tc.name = '#{CategoryExperts::TOPIC_NEEDS_EXPERT_POST_APPROVAL}' AND
              tc.value <> '0'
        )
    SQL

  on(:post_created) do |post, opts, user|
    handler = CategoryExperts::PostHandler.new(post: post, user: user)
    handler.process_new_post
    if opts[:is_category_expert_question].to_s == "true" && post.is_first_post?
      handler.mark_topic_as_question
    end
  end

  on(:post_moved) do |post, original_topic_id, original_post|
    if original_post&.id && original_post.id != post.id
      # The post was duplicated using `freeze_original`, check if the original post was category experts post
      # and if so, dupliate custom fields over to new topic
      expert_group_name = original_post.custom_fields[CategoryExperts::POST_APPROVED_GROUP_NAME]
      next if expert_group_name.nil?

      # The old post was an expert post -- mark the new post as approved!
      CategoryExperts::PostHandler.new(post: post).mark_post_as_approved
    else
      # Post was moved, not duplicated. We now have to correct the original topic if it still exists,
      # and update the new topic custom fields
      expert_group_name = post.custom_fields[CategoryExperts::POST_APPROVED_GROUP_NAME]
      next if expert_group_name.nil?

      original_topic = Topic.find_by(id: original_topic_id)

      # Correct original_topic custom fields for topic the post was moved FROM
      if original_topic
        CategoryExperts::PostHandler.new(
          topic: original_topic,
        ).correct_topic_custom_fields_after_removal(group_name: expert_group_name)
      end

      # Now add the correct custom fields to the new topic the post was moved TO
      CategoryExperts::PostHandler.new(post: post).correct_topic_custom_fields_after_addition
    end
  end

  on(:post_owner_changed) do |post, old_owner, new_owner|
    previously_approved = !post.custom_fields[CategoryExperts::POST_PENDING_EXPERT_APPROVAL]
    post.custom_fields.delete(CategoryExperts::POST_APPROVED_GROUP_NAME)
    post.custom_fields.delete(CategoryExperts::POST_PENDING_EXPERT_APPROVAL)
    post.save!
    CategoryExperts::PostHandler.new(post: post, user: new_owner).process_new_post(
      previously_approved: previously_approved,
    )
  end

  add_to_class(:group, :category_expert_category_ids) do
    category_ids = []

    CategoryCustomField
      .where(name: CategoryExperts::CATEGORY_EXPERT_GROUP_IDS)
      .where.not(value: nil)
      .where.not(value: "")
      .pluck(:category_id, :value)
      .each do |category_id, group_ids|
        category_ids.push(category_id) if group_ids.split("|").map(&:to_i).include?(self.id)
      end

    category_ids
  end

  on(:user_added_to_group) do |user, group|
    next if !SiteSetting.approve_past_posts_on_becoming_category_expert

    category_ids = group.category_expert_category_ids
    next if category_ids.empty?

    ::Jobs.enqueue(
      :approve_past_category_expert_posts,
      user_id: user.id,
      category_ids: category_ids,
    )
  end

  on(:user_removed_from_group) do |user, group|
    category_ids = group.category_expert_category_ids
    next if category_ids.empty?

    ::Jobs.enqueue(
      :unapprove_past_category_expert_posts,
      user_id: user.id,
      category_ids: category_ids,
    )
  end

  # outgoing webhook events
  %i[category_experts_approved category_experts_unapproved].each do |category_experts_event|
    on(category_experts_event) do |post|
      if WebHook.active_web_hooks(category_experts_event).exists?
        payload = WebHook.generate_payload(:post, post)
        WebHook.enqueue_category_experts_hooks(category_experts_event, post, payload)
      end
    end
  end

  Discourse::Application.routes.append do
    put "category-experts/endorse/:username" => "category_experts#endorse",
        :constraints => {
          username: ::RouteFormat.username,
        }
    post "category-experts/approve" => "category_experts#approve_post"
    post "category-experts/unapprove" => "category_experts#unapprove_post"
    get "category-experts/endorsable-categories/:username" =>
          "category_experts#endorsable_categories",
        :constraints => {
          username: ::RouteFormat.username,
        }
  end
end
