class DartSetupsController < ApplicationController
  before_action :require_premium_access

  def edit
    @dart_setup = current_dart_setup
    @setup_stats = DartSetupStats.new(user: Current.user).grouped
  end

  def update
    @dart_setup = current_dart_setup

    if @dart_setup.update(dart_setup_params)
      redirect_to edit_dart_setup_path, notice: "Dart setup saved. New matches will track stats against this setup."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def current_dart_setup
    Current.user.dart_setup || Current.user.build_dart_setup(default_setup_attributes)
  end

  def default_setup_attributes
    {
      manufacturer: "winmau",
      weight_g: 23.0,
      shaft_type: "nylon",
      shaft_length_mm: 40,
      point_length_mm: 32
    }
  end

  def dart_setup_params
    params.require(:dart_setup).permit(:manufacturer, :weight_g, :shaft_type, :shaft_length_mm, :point_length_mm)
  end
end
