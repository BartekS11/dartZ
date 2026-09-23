class AddOnboardingGuideVersionToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :onboarding_guide_version, :integer, default: 0, null: false
  end
end
