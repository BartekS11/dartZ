module Social
  class Error < StandardError
    attr_reader :code, :status, :details

    def initialize(message, code: "validation_failed", status: :unprocessable_entity, details: nil)
      super(message)
      @code = code
      @status = status
      @details = details
    end

    def self.not_found
      new("User is unavailable", code: "not_found", status: :not_found)
    end

    def self.forbidden(message = "This action is not allowed")
      new(message, code: "forbidden", status: :forbidden)
    end

    def self.conflict(message)
      new(message, code: "conflict", status: :conflict)
    end
  end
end
