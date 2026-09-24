module Social
  class Privacy
    class << self
      def blocked?(user_a, user_b)
        UserBlock.where(blocker: user_a, blocked: user_b)
          .or(UserBlock.where(blocker: user_b, blocked: user_a)).exists?
      end

      def ensure_available!(user_a, user_b)
        raise Error.not_found if user_a == user_b || blocked?(user_a, user_b)
      end
    end
  end
end
