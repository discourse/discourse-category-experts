# frozen_string_literal: true

Fabricator(:outgoing_category_experts_web_hook, from: :web_hook) do
  payload_url "https://meta.discourse.org/webhook_listener"
  content_type WebHook.content_types["application/json"]
  wildcard_web_hook false
  secret "my_lovely_secret_for_web_hook"
  verify_certificate true
  active true

  after_build do |web_hook|
    web_hook.web_hook_event_types = WebHookEventType.where(name: %w[category_experts_approved])
  end
end
