module Admin
  class DataCleanupsController < BaseController
    before_action :set_user
    before_action :set_cleanup, only: %i[restore purge]

    def create
      cleanup = Admin::AccountDataCleanup.clear!(
        user: @user,
        admin_user: current_admin_user,
        categories: params[:categories],
        reason: params[:reason],
        confirmation_email: params[:confirmation_email],
        acknowledged: params[:confirmation_acknowledgement]
      )
      redirect_to admin_user_path(@user), notice: "Data cleared in batch #{cleanup.public_id}."
    rescue Admin::AccountDataCleanup::Error, ActiveRecord::RecordInvalid, ActiveRecord::RecordNotDestroyed => error
      redirect_to admin_user_path(@user), alert: error.message
    end

    def restore
      Admin::AccountDataCleanup.restore!(
        cleanup: @cleanup,
        admin_user: current_admin_user,
        reason: params[:reason],
        confirmation_email: params[:confirmation_email],
        acknowledged: params[:confirmation_acknowledgement]
      )
      redirect_to admin_user_path(@user), notice: "Cleanup batch restored."
    rescue Admin::AccountDataCleanup::Error, ActiveRecord::RecordInvalid, ActiveRecord::RecordNotDestroyed => error
      redirect_to admin_user_path(@user), alert: error.message
    end

    def purge
      Admin::AccountDataCleanup.purge!(
        cleanup: @cleanup,
        admin_user: current_admin_user,
        reason: params[:reason],
        confirmation_email: params[:confirmation_email],
        acknowledged: params[:confirmation_acknowledgement]
      )
      redirect_to admin_user_path(@user), notice: "Cleanup batch permanently purged."
    rescue Admin::AccountDataCleanup::Error, ActiveRecord::RecordInvalid, ActiveRecord::RecordNotDestroyed => error
      redirect_to admin_user_path(@user), alert: error.message
    end

    private

    def set_user
      @user = User.find(params[:user_id])
    end

    def set_cleanup
      @cleanup = @user.admin_data_cleanups.find_by_public_id!(params[:id])
    end
  end
end
