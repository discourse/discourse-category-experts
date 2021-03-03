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
  ].each { |path| require File.expand_path(path, __FILE__) }

  module ::CategoryExperts
    PLUGIN_NAME ||= "discourse-category-experts".freeze
    CATEGORY_EXPERT_GROUP_IDS = "category_expert_group_ids"
    CATEGORY_ACCEPTING_ENDORSEMENTS = "category_accepting_endorsements"

    class Engine < ::Rails::Engine
      engine_name CategoryExperts::PLUGIN_NAME
      isolate_namespace CategoryExperts
    end
  end

  register_reviewable_type ReviewableCategoryExpertSuggestion
  add_permitted_reviewable_param(:reviewable_category_expert_suggestion, :group_id)

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

  Discourse::Application.routes.append do
    put "category-experts/endorse/:username" => "category_experts#endorse", constraints: { username: ::RouteFormat.username }
  end
end
