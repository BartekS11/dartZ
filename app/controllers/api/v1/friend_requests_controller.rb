module Api
  module V1
    class FriendRequestsController < SocialController
      rate_limit to: 20, within: 1.hour, only: :create, by: -> { current_api_user&.id || request.remote_ip },
        with: -> { render_rate_limited }

      def index
        scope = FriendRequest.for_user(current_api_user).pending.includes(:requester, :recipient)
          .order(created_at: :desc, public_id: :desc)
        records, pagination = paginate(scope)
        users = records.map { |record| record.other_user(current_api_user) }
        serializer = serializer_for(users)
        render json: { data: records.map { |record| serializer.request(record) }, pagination: pagination }
      end

      def create
        request_record = Social::FriendshipManager.send_request(
          actor: current_api_user,
          target: find_target,
          share_code: params[:share_code]
        )
        serializer = serializer_for([ request_record.recipient ])
        render json: { data: serializer.request(request_record) }, status: :created
      end

      def accept
        friendship = Social::FriendshipManager.accept(actor: current_api_user, request: find_request)
        serializer = serializer_for([ friendship.other_user(current_api_user) ])
        render json: { data: serializer.friendship(friendship) }
      end

      def decline
        request_record = find_request
        Social::FriendshipManager.decline(actor: current_api_user, request: request_record)
        serializer = serializer_for([ request_record.requester ])
        render json: { data: serializer.request(request_record) }
      end

      def destroy
        Social::FriendshipManager.cancel(actor: current_api_user, request: find_request)
        head :no_content
      end

      private

      def find_request
        FriendRequest.find_by_public_id!(params[:id])
      end

      def render_rate_limited
        response.set_header("Retry-After", "3600")
        render_api_error(code: "rate_limited", message: "Too many friend requests", status: :too_many_requests)
      end
    end
  end
end
