module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :current_user, :guest_id

    def connect
      # Try JWT token first (mobile)
      token = request.params[:token] || request.headers["Authorization"]&.split(" ")&.last

      if token
        connect_via_jwt(token)
      else
        connect_via_session
      end
    end

    private

    def connect_via_jwt(token)
      decoded     = JsonWebToken.decode(token)
      if decoded[:guest]
        self.guest_id    = decoded[:guest_id]
        self.current_user = nil
      else
        self.current_user = User.find(decoded[:user_id])
        self.guest_id     = nil
      end
    rescue ExceptionHandler::InvalidToken
      reject_unauthorized_connection
    end

    def connect_via_session
      if (session_id = cookies.signed[:session_id])
        self.current_user = Session.find_by(id: session_id)&.user
        self.guest_id = nil
      else
        self.guest_id = SecureRandom.uuid
        self.current_user = nil
      end
    end
  end
end
