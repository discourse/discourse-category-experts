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
    "../app/models/user_endorsement",
  ].each { |path| require File.expand_path(path, __FILE__) }

  module ::CategoryExperts
    PLUGIN_NAME ||= "discourse-category-experts".freeze
    CATEGORY_EXPERT_GROUP_ID = "category_expert_group_id"
    CATEGORY_ACCEPTING_ENDORSEMENTS = "category_accepting_endorsements"

    class Engine < ::Rails::Engine
      engine_name CategoryExperts::PLUGIN_NAME
      isolate_namespace CategoryExperts
    end
  end

  if Site.respond_to? :preloaded_category_custom_fields
    Site.preloaded_category_custom_fields << CategoryExperts::CATEGORY_EXPERT_GROUP_ID
    Site.preloaded_category_custom_fields << CategoryExperts::CATEGORY_ACCEPTING_ENDORSEMENTS
  end

  reloadable_patch do
    User.class_eval do
      has_many :given_user_endorsements, foreign_key: "user_id", class_name: "UserEndorsement"
      has_many :recieved_user_endorsements, foreign_key: "endorsed_user_id", class_name: "UserEndorsement"
    end
  end

  add_to_class(:user, :given_user_endorsements_for) do |user|
    given_user_endorsements.where(endorsed_user_id: user.id)
  end

  add_to_class(:category, :accepting_user_endorsements?) do
    custom_fields[CategoryExperts::CATEGORY_EXPERT_GROUP_ID] &&
      custom_fields[CategoryExperts::CATEGORY_ACCEPTING_ENDORSEMENTS]
  end

  add_to_serializer(:user_card, :user_endorsements) do
    return unless SiteSetting.enable_category_experts
    return if !scope.current_user || scope.current_user == object

    scope.current_user.given_user_endorsements_for(object)
  end

  Discourse::Application.routes.append do
    put "category-experts/endorse/:username" => "category_experts#endorse", constraints: { username: ::RouteFormat.username }
  end
end
