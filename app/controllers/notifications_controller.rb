class NotificationsController < ApplicationController
  before_action -> { require_roadmap_feature!(:web_push) }

  def show
    @preference = Current.user.notification_preference || Current.user.create_notification_preference!
    @subscriptions = Current.user.push_subscriptions.active.order(created_at: :desc)
    @vapid_public_key = Rails.application.config.x.web_push.public_key
  end

  def update
    preference = Current.user.notification_preference || Current.user.build_notification_preference
    preference.update!(preference_params)
    redirect_to notifications_path, notice: t("push.flashes.preferences_updated")
  rescue ActiveRecord::RecordInvalid
    redirect_to notifications_path, alert: t("push.flashes.invalid_preferences")
  end

  private

  def preference_params
    params.require(:notification_preference).permit(*NotificationPreference::CATEGORIES)
  end
end
