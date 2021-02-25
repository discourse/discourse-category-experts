# frozen_string_literal: true

# name: discourse-category-experts
# about: Distinguish groups of users as experts in categories.
# version: 0.0.1
# authors: Mark VanLandingham
# url: https://github.com/discourse/discourse-category-experts
# transpile_js: true

after_initialize do
  [
    # "../app/models/webinar",
  ].each { |path| require File.expand_path(path, __FILE__) }

  module ::CategoryExperts
    PLUGIN_NAME ||= "discourse-category-experts".freeze

    class Engine < ::Rails::Engine
      engine_name CategoryExperts::PLUGIN_NAME
      isolate_namespace CategoryExperts
    end
  end

  Site.preloaded_category_custom_fields << "category_expert_group_id" if Site.respond_to? :preloaded_category_custom_fields
end
