module PushNotifications
  class DeliveryError < StandardError
    attr_reader :code

    def initialize(message, code: "delivery_error")
      @code = code
      super(message)
    end
  end
end
