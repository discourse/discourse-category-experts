# frozen_string_literal: true

# name: discourse-category-experts
# about: Distinguish groups of users as experts in categories.
# version: 0.0.1
# authors: Mark VanLandingham
# url: https://github.com/discourse/discourse-category-experts
# transpile_js: true

register_asset "stylesheets/common.scss"

enabled_site_setting :enable_category_experts

after_initialize do
  [
    "../app/controllers/category_experts_controller",
    "../app/models/category_expert_endorsement",
    "../app/models/reviewable_category_expert_suggestion",
    "../app/serializers/reviewable_category_expert_suggestion_serializer",
    "../app/jobs/scheduled/remind_admin_of_category_experts_posts_job",
    "../app/jobs/scheduled/remind_category_experts_job",
    "../lib/category_experts/post_handler",
  ].each { |path| require File.expand_path(path, __FILE__) }

  module ::CategoryExperts
    PLUGIN_NAME ||= "discourse-category-experts".freeze
    CATEGORY_EXPERT_GROUP_IDS = "category_expert_group_ids"
    CATEGORY_ACCEPTING_ENDORSEMENTS = "category_accepting_endorsements"
    CATEGORY_ACCEPTING_QUESTIONS = "category_accepting_questions"
    CATEGORY_BADGE_ID = "category_experts_badge_id"
    POST_APPROVED_GROUP_NAME = "category_expert_post"
    POST_PENDING_EXPERT_APPROVAL = "category_expert_post_pending"
    TOPIC_EXPERT_POST_GROUP_NAMES = "category_expert_topic_approved_group_names"
    TOPIC_NEEDS_EXPERT_POST_APPROVAL = "category_expert_topic_post_needs_approval"
    TOPIC_IS_CATEGORY_EXPERT_QUESTION = "category_expert_topic_is_question"

    class Engine < ::Rails::Engine
      engine_name CategoryExperts::PLUGIN_NAME
      isolate_namespace CategoryExperts
    end
  end

  register_reviewable_type ReviewableCategoryExpertSuggestion

  add_permitted_reviewable_param(:reviewable_category_expert_suggestion, :group_id)

  add_custom_reviewable_filter(
    [
      :endorsed_username,
      Proc.new do |results, value|
        user_id = User.find_by_username(value)&.id
        return results if user_id.blank?
        results
          .joins("INNER JOIN category_expert_endorsements ON category_expert_endorsements.id = target_id")
          .where("category_expert_endorsements.endorsed_user_id = ?", user_id)
      end
    ]
  )

  register_post_custom_field_type(CategoryExperts::POST_APPROVED_GROUP_NAME, :string)
  register_post_custom_field_type(CategoryExperts::POST_PENDING_EXPERT_APPROVAL, :boolean)

  register_topic_custom_field_type(CategoryExperts::TOPIC_EXPERT_POST_GROUP_NAMES, :string)
  register_topic_custom_field_type(CategoryExperts::TOPIC_NEEDS_EXPERT_POST_APPROVAL, :boolean)
  register_topic_custom_field_type(CategoryExperts::TOPIC_IS_CATEGORY_EXPERT_QUESTION, :boolean)

  [
    CategoryExperts::TOPIC_EXPERT_POST_GROUP_NAMES,
    CategoryExperts::TOPIC_NEEDS_EXPERT_POST_APPROVAL,
    CategoryExperts::TOPIC_IS_CATEGORY_EXPERT_QUESTION
  ].each do |field|
    TopicList.preloaded_custom_fields << field
    Search.preloaded_topic_custom_fields << field
  end

  register_category_custom_field_type(CategoryExperts::CATEGORY_EXPERT_GROUP_IDS, :string)
  register_category_custom_field_type(CategoryExperts::CATEGORY_ACCEPTING_ENDORSEMENTS, :boolean)
  register_category_custom_field_type(CategoryExperts::CATEGORY_ACCEPTING_QUESTIONS, :boolean)
  register_category_custom_field_type(CategoryExperts::CATEGORY_BADGE_ID, :string)

  Site.preloaded_category_custom_fields << CategoryExperts::CATEGORY_EXPERT_GROUP_IDS
  Site.preloaded_category_custom_fields << CategoryExperts::CATEGORY_ACCEPTING_ENDORSEMENTS
  Site.preloaded_category_custom_fields << CategoryExperts::CATEGORY_ACCEPTING_QUESTIONS
  Site.preloaded_category_custom_fields << CategoryExperts::CATEGORY_BADGE_ID

  add_permitted_post_update_param(:is_category_expert_question) do |post, is_category_expert_question|
    if post.is_first_post?
      topic = post.topic
      topic.custom_fields[CategoryExperts::TOPIC_IS_CATEGORY_EXPERT_QUESTION] = is_category_expert_question.to_s == "true"
      topic.save!
    end
  end

  reloadable_patch do
    User.class_eval do
      has_many :given_category_expert_endorsements, foreign_key: "user_id", class_name: "CategoryExpertEndorsement"
      has_many :received_category_expert_endorsements, foreign_key: "endorsed_user_id", class_name: "CategoryExpertEndorsement"
    end
  end

  add_to_class(:user, :given_category_expert_endorsements_for) do |user|
    given_category_expert_endorsements.where(endorsed_user_id: user.id)
  end

  add_to_serializer(:current_user, :expert_for_category_ids) do
    user_group_ids = object.group_ids
    return [] if user_group_ids.empty?

    CategoryCustomField
      .where(name: CategoryExperts::CATEGORY_EXPERT_GROUP_IDS)
      .select { |custom_field| (custom_field.value.split("|").map(&:to_i) & user_group_ids).count > 0 }
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
    object.custom_fields[CategoryExperts::POST_APPROVED_GROUP_NAME]
  end

  add_to_serializer(:post, :needs_category_expert_approval) do
    object.custom_fields[CategoryExperts::POST_PENDING_EXPERT_APPROVAL]
  end

  add_to_serializer(:post, :can_manage_category_expert_posts) do
    scope.is_staff?
  end

  add_to_class(:topic, :is_category_expert_question?) do
    custom_fields[CategoryExperts::TOPIC_IS_CATEGORY_EXPERT_QUESTION] &&
      !category.custom_fields[CategoryExperts::CATEGORY_EXPERT_GROUP_IDS].blank?
  end

  reloadable_patch do
    [:topic_list_item, :search_topic_list_item].each do |serializer|
      add_to_serializer(serializer, :needs_category_expert_post_approval) do
        true
      end

      add_to_serializer(serializer, :include_needs_category_expert_post_approval?) do
        scope.is_staff? && object.custom_fields[CategoryExperts::TOPIC_NEEDS_EXPERT_POST_APPROVAL]
      end

      add_to_serializer(serializer, :expert_post_group_names) do
        object.custom_fields[CategoryExperts::TOPIC_EXPERT_POST_GROUP_NAMES].split("|")
      end

      add_to_serializer(serializer, :include_expert_post_group_names?) do
        !object.custom_fields[CategoryExperts::TOPIC_EXPERT_POST_GROUP_NAMES].blank?
      end

      add_to_serializer(serializer, :is_category_expert_question) do
        true
      end

      add_to_serializer(serializer, :include_is_category_expert_question?) do
        object.is_category_expert_question?
      end
    end
  end

  add_to_serializer(:topic_view, :is_category_expert_question) do
    object.topic.is_category_expert_question?
  end

  add_to_serializer(:topic_view, :expert_post_group_names) do
    object.topic.custom_fields[CategoryExperts::TOPIC_EXPERT_POST_GROUP_NAMES].split("|")
  end

  add_to_serializer(:topic_view, :include_expert_post_group_names?) do
    !object.topic.custom_fields[CategoryExperts::TOPIC_EXPERT_POST_GROUP_NAMES].blank?
  end

  add_permitted_post_create_param(:is_category_expert_question)

  if Search.respond_to? :preloaded_topic_custom_fields
    Search.preloaded_topic_custom_fields << CategoryExperts::TOPIC_EXPERT_POST_GROUP_NAMES
    Search.preloaded_topic_custom_fields << CategoryExperts::TOPIC_IS_CATEGORY_EXPERT_QUESTION
  end

  register_search_advanced_filter(/with:category_expert_response/) do |posts|
    posts.where("topics.id IN (
        SELECT tc.topic_id
        FROM topic_custom_fields tc
        WHERE tc.name = '#{CategoryExperts::TOPIC_EXPERT_POST_GROUP_NAMES}' AND
              tc.value <> ''
        )")
  end

  register_search_advanced_filter(/is:category_expert_question/) do |posts|
    posts.where(<<~SQL)
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
  end

  register_search_advanced_filter(/without:category_expert_post/) do |posts|
    posts.where(<<~SQL)
      topics.id IN (
        SELECT topics.id
        FROM topics
        EXCEPT
        SELECT topics.id
        FROM topics
        INNER JOIN topic_custom_fields tc ON topics.id = tc.topic_id
        WHERE (tc.name = '#{CategoryExperts::TOPIC_NEEDS_EXPERT_POST_APPROVAL}' AND
              tc.value = 't')
        OR (tc.name = '#{CategoryExperts::TOPIC_EXPERT_POST_GROUP_NAMES}' AND
              tc.value <> '' AND
              tc.value IS NOT NULL)
        )
    SQL
  end

  register_search_advanced_filter(/with:unapproved_ce_post/) do |posts|
    posts.where(<<~SQL)
      topics.id IN (
        SELECT topics.id
        FROM topics
        INNER JOIN topic_custom_fields tc ON topics.id = tc.topic_id
        WHERE tc.name = '#{CategoryExperts::TOPIC_NEEDS_EXPERT_POST_APPROVAL}' AND
              tc.value = 't'
        )
    SQL
  end

  NewPostManager.add_handler do |manager|
    result = manager.perform_create_post

    if result.success?
      post = result.post
      handler = CategoryExperts::PostHandler.new(post: post, user: manager.user)
      handler.process_new_post
      handler.mark_topic_as_question if manager.args[:is_category_expert_question] && post.is_first_post?
    end

    result
  end

  Discourse::Application.routes.append do
    put "category-experts/endorse/:username" => "category_experts#endorse", constraints: { username: ::RouteFormat.username }
    post "category-experts/approve" => "category_experts#approve_post"
    post "category-experts/unapprove" => "category_experts#unapprove_post"
    get "category-experts/retroactive-approval/:post_id" => "category_experts#retroactive_approval?"
  end
end
