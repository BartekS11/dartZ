class HomeController < ApplicationController
  allow_unauthenticated_access
  before_action :resume_session_optional

  def show
  end
end
