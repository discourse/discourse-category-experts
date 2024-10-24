# frozen_string_literal: true
WebHookEventType.seed do |b|
  b.id = WebHookEventType::CATEGORY_EXPERTS_APPROVED
  b.name = "category_experts_approved"
  b.group = WebHookEventType.groups[:post]
end
WebHookEventType.seed do |b|
  b.id = WebHookEventType::CATEGORY_EXPERTS_UNAPPROVED
  b.name = "category_experts_unapproved"
  b.group = WebHookEventType.groups[:post]
end
