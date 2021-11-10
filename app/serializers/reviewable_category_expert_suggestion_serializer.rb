# frozen_string_literal: true

require_dependency 'reviewable_serializer'

class ReviewableCategoryExpertSuggestionSerializer < ReviewableSerializer
  attributes :endorsed_by, :endorsed_count

  has_one :user, serializer: BasicUserSerializer, root: false, embed: :objects

  def endorsed_users
    @endorsed_users ||= CategoryExpertEndorsement
      .includes(:user)
      .where(category_id: object.target.category_id, endorsed_user_id: object.target.endorsed_user_id)
      .map(&:user)
  end

  def endorsed_by
    ActiveModel::ArraySerializer.new(
      endorsed_users,
      each_serializer: BasicUserSerializer,
      root: nil,
    )
  end

  def endorsed_count
    endorsed_users.count
  end

  def category_id
    object.target.category_id
  end

  def include_category_id?
    true
  end

  def user
    object.target.endorsed_user
  end
end
