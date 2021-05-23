# frozen_string_literal: true

require 'rate_limiter'

module CategoryExperts
  class EndorsementRateLimiter < RateLimiter
    def initialize(user)
      limit = SiteSetting.max_category_expert_endorsements_per_day

      if user.trust_level >= 2
        multiplier = SiteSetting.get("tl#{user.trust_level}_additional_category_expert_endorsements_per_day_multiplier").to_f
        multiplier = 1.0 if multiplier < 1.0
        limit = (limit * multiplier).to_i
      end

      super(user, "category-expert-endorsement", limit, 1.day.to_i)
    end

    def build_key(type)
      "#{super(type)}:#{Date.today}"
    end
  end
end
