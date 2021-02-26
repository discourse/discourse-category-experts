# frozen_string_literal: true

require_dependency 'reviewable_serializer'

class ReviewableCategoryExpertSuggestionSerializer < ReviewableSerializer
  attributes :endorsed_by, :endorsed_count, :category, :user

  def endorsed_users
    @endorsed_users ||= UserEndorsement
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

  def category
    BasicCategorySerializer.new(object.target.category, root: false).as_json
  end

  def user
    BasicUserSerializer.new(object.target.endorsed_user, root: false).as_json
  end
end
