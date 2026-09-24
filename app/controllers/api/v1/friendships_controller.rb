module Api
  module V1
    class FriendshipsController < SocialController
      def index
        scope = Friendship.for_user(current_api_user).includes(:user_low, :user_high).order(created_at: :desc, public_id: :desc)
        records, pagination = paginate(scope)
        serializer = serializer_for(records.map { |record| record.other_user(current_api_user) })
        render json: { data: records.map { |record| serializer.friendship(record) }, pagination: pagination }
      end

      def destroy
        Social::FriendshipManager.remove(
          actor: current_api_user,
          friendship: Friendship.find_by_public_id!(params[:id])
        )
        head :no_content
      end
    end
  end
end
