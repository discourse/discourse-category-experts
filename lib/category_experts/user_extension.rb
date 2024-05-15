# frozen_string_literal: true

module CategoryExperts
  module UserExtension
    extend ActiveSupport::Concern

    prepended do
      has_many :given_category_expert_endorsements,
               foreign_key: "user_id",
               class_name: "CategoryExpertEndorsement"
      has_many :received_category_expert_endorsements,
               foreign_key: "endorsed_user_id",
               class_name: "CategoryExpertEndorsement"
    end
  end
end
