module ExceptionHandler
  extend ActiveSupport::Concern

  class InvalidToken    < StandardError; end
  class MissingToken    < StandardError; end
  class Unauthorized    < StandardError; end

  included do
    rescue_from InvalidToken,    with: :unauthorized
    rescue_from MissingToken,    with: :unauthorized
    rescue_from Unauthorized,    with: :unauthorized
    rescue_from ActiveRecord::RecordNotFound, with: :not_found
  end

  private

  def unauthorized(e)
    render json: { error: e.message }, status: :unauthorized
  end

  def not_found(e)
    render json: { error: e.message }, status: :not_found
  end
end
