module Api
  module V1
    class AuthController < BaseController
      skip_before_action :authenticate_api_user!

      def register
        user = User.new(
          email_address: params[:email],
          password:      params[:password]
        )

        if user.save
          token = JsonWebToken.encode(user_id: user.id)
          render json: {
            token: token,
            user:  { id: user.id, email: user.email_address }
          }, status: :created
        else
          render json: { errors: user.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def login
        user = User.find_by(email_address: params[:email])

        if user&.authenticate(params[:password])
          token = JsonWebToken.encode(user_id: user.id)
          render json: {
            token: token,
            user:  { id: user.id, email: user.email_address }
          }
        else
          render json: { error: "Invalid email or password" }, status: :unauthorized
        end
      end

      def guest
        token = JsonWebToken.encode(guest: true, guest_id: SecureRandom.uuid)
        render json: { token: token, guest: true }
      end
    end
  end
end
