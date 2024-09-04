# frozen_string_literal: true

module CategoryExperts
  module OutgoingWebHookExtension
    def self.prepended(base)
      def base.enqueue_category_experts_hooks(event, post, payload = nil)
        if active_web_hooks(event).exists?
          payload ||= WebHook.generate_payload(:post, post)

          WebHook.enqueue_hooks(
            :post,
            event,
            id: post.id,
            category_id: post.topic&.category_id,
            tag_ids: post.topic&.tags&.pluck(:id),
            payload: payload,
          )
        end
      end
    end
  end
end
