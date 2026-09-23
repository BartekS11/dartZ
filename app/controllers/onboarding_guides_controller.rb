class OnboardingGuidesController < ApplicationController
  before_action :require_authentication

  def update
    version = params.require(:onboarding_guide).permit(:version).fetch(:version)
    version = Integer(version)
    raise ActionController::BadRequest unless version.between?(0, 10_000)

    Current.user.update!(onboarding_guide_version: [ Current.user.onboarding_guide_version, version ].max)
    head :no_content
  rescue ArgumentError, TypeError
    raise ActionController::BadRequest
  end
end
