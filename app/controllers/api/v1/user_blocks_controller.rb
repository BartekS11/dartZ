module Api
  module V1
    class UserBlocksController < SocialController
      def index
        scope = current_api_user.blocks_created.includes(:blocked).order(created_at: :desc, public_id: :desc)
        records, pagination = paginate(scope)
        serializer = serializer_for(records.map(&:blocked))
        render json: { data: records.map { |record| serializer.block(record) }, pagination: pagination }
      end

      def create
        block = Social::FriendshipManager.block(actor: current_api_user, target: find_target)
        serializer = serializer_for([ block.blocked ])
        render json: { data: serializer.block(block) }, status: :created
      end

      def destroy
        Social::FriendshipManager.unblock(
          actor: current_api_user,
          block: UserBlock.find_by_public_id!(params[:id])
        )
        head :no_content
      end
    end
  end
end
