# frozen_string_literal: true

# name: discourse-category-experts
# about: Distinguish groups of users as experts in categories.
# version: 0.0.1
# authors: Mark VanLandingham
# url: https://github.com/discourse/discourse-category-experts
# transpile_js: true

register_asset "stylesheets/common.scss"

after_initialize do
  [
    "../app/controllers/category_experts_controller",
    "../app/models/category_expert_endorsement",
    "../app/models/reviewable_category_expert_suggestion",
    "../app/serializers/reviewable_category_expert_suggestion_serializer",
    "../lib/category_experts/post_handler",
  ].each { |path| require File.expand_path(path, __FILE__) }

  module ::CategoryExperts
    PLUGIN_NAME ||= "discourse-category-experts".freeze
    CATEGORY_EXPERT_GROUP_IDS = "category_expert_group_ids"
    CATEGORY_ACCEPTING_ENDORSEMENTS = "category_accepting_endorsements"
    IS_APPROVED_EXPERT_POST = "category_expert_post"
    POST_PENDING_EXPERT_APPROVAL = "category_expert_post_pending"
    TOPIC_HAS_APPROVED_EXPERT_POST = "category_expert_topic_approved_post"
    TOPIC_NEEDS_EXPERT_POST_APPROVAL = "category_expert_topic_post_needs_approval"

    class Engine < ::Rails::Engine
      engine_name CategoryExperts::PLUGIN_NAME
      isolate_namespace CategoryExperts
    end
  end

  register_reviewable_type ReviewableCategoryExpertSuggestion

  add_permitted_reviewable_param(:reviewable_category_expert_suggestion, :group_id)

  register_post_custom_field_type(CategoryExperts::IS_APPROVED_EXPERT_POST, :string)
  register_post_custom_field_type(CategoryExperts::POST_PENDING_EXPERT_APPROVAL, :boolean)

  register_topic_custom_field_type(CategoryExperts::TOPIC_HAS_APPROVED_EXPERT_POST, :boolean)
  register_topic_custom_field_type(CategoryExperts::TOPIC_NEEDS_EXPERT_POST_APPROVAL, :boolean)

  if Site.respond_to? :preloaded_category_custom_fields
    Site.preloaded_category_custom_fields << CategoryExperts::CATEGORY_EXPERT_GROUP_IDS
    Site.preloaded_category_custom_fields << CategoryExperts::CATEGORY_ACCEPTING_ENDORSEMENTS
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

  add_to_class(:category, :accepting_category_expert_endorsements?) do
    custom_fields[CategoryExperts::CATEGORY_EXPERT_GROUP_IDS] &&
      custom_fields[CategoryExperts::CATEGORY_ACCEPTING_ENDORSEMENTS]
  end

  add_to_serializer(:user_card, :category_expert_endorsements) do
    return unless SiteSetting.enable_category_experts
    return if !scope.current_user || scope.current_user == object

    scope.current_user.given_category_expert_endorsements_for(object)
  end

  add_to_serializer(:post, :category_expert_approved) do
    object.custom_fields[CategoryExperts::IS_APPROVED_EXPERT_POST]
  end

  add_to_serializer(:post, :needs_category_expert_approval) do
    object.custom_fields[CategoryExperts::POST_PENDING_EXPERT_APPROVAL]
  end

  add_to_serializer(:post, :can_manage_category_expert_posts) do
    scope.is_staff?
  end

  NewPostManager.add_handler do |manager|
    result = manager.perform_create_post

    if result.success?
      handler = CategoryExperts::PostHandler.new(post: result.post, user: manager.user)
      handler.process_new_post
    end

    result
  end

  Discourse::Application.routes.append do
    put "category-experts/endorse/:username" => "category_experts#endorse", constraints: { username: ::RouteFormat.username }
    post "category-experts/approve" => "category_experts#approve_post"
    post "category-experts/unapprove" => "category_experts#unapprove_post"
  end
end
