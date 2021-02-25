# frozen_string_literal: true

# name: discourse-category-experts
# about: Distinguish groups of users as experts in categories.
# version: 0.0.1
# authors: Mark VanLandingham
# url: https://github.com/discourse/discourse-category-experts
# transpile_js: true

after_initialize do
  [
    "../app/models/user_endorsement",
  ].each { |path| require File.expand_path(path, __FILE__) }

  module ::CategoryExperts
    PLUGIN_NAME ||= "discourse-category-experts".freeze

    class Engine < ::Rails::Engine
      engine_name CategoryExperts::PLUGIN_NAME
      isolate_namespace CategoryExperts
    end
  end

  if Site.respond_to? :preloaded_category_custom_fields
    Site.preloaded_category_custom_fields << "category_expert_group_id"
    Site.preloaded_category_custom_fields << "accepting_expert_endorsements"
  end

  reloadable_patch do
    User.class_eval do
      has_many :given_user_endorsements, foreign_key: "user_id", class_name: "UserEndorsement"
      has_many :recieved_user_endorsements, foreign_key: "endorsed_user_id", class_name: "UserEndorsement"

      def given_user_endorsements_for(user)
        given_user_endorsements.where(endorsed_user_id: user.id)
      end
    end
  end

  add_to_serializer(:user_card, :user_endorsements) do
    return unless SiteSetting.enable_category_experts
    return if !scope.current_user || scope.current_user == object

    scope.current_user.given_user_endorsements_for(object)
  end
end
