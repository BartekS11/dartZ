require "test_helper"

class RoadmapLocalizationContractTest < ActiveSupport::TestCase
  REQUIRED_KEYS = %w[
    common.pagination.previous
    common.pagination.next
    common.pagination.page
    common.pagination.results
    common.states.empty
    common.states.feature_unavailable
    common.states.offline
    common.states.online
    common.states.sync_pending
    common.notifications.permission_default
    common.notifications.permission_granted
    common.notifications.permission_denied
  ].freeze

  test "shared roadmap copy exists in every supported locale" do
    User::LOCALES.each do |locale|
      REQUIRED_KEYS.each do |key|
        translation = I18n.t(key, locale: locale, default: nil)

        assert translation.present?, "Missing #{locale}.#{key}"
      end
    end
  end
end
