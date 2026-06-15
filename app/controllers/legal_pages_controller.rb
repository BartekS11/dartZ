class LegalPagesController < ApplicationController
  allow_unauthenticated_access

  def privacy; end
  def terms; end
  def contact; end
end
