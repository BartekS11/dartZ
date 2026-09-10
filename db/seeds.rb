admin_email = ENV["ADMIN_EMAIL"].to_s.strip
admin_password = ENV["ADMIN_PASSWORD"].to_s
admin_path = ENV["ADMIN_PATH"].to_s.strip
admin_values = [ admin_email, admin_password, admin_path ]

if Rails.env.production? && admin_values.any?(&:blank?)
  raise "ADMIN_EMAIL, ADMIN_PASSWORD, and ADMIN_PATH are required in production"
end

if admin_values.any?(&:present?) && admin_values.any?(&:blank?)
  raise "Set ADMIN_EMAIL, ADMIN_PASSWORD, and ADMIN_PATH together"
end

if admin_values.all?(&:present?)
  raise "ADMIN_PASSWORD must be at least 16 characters" if admin_password.length < 16
  raise "ADMIN_PATH must be one URL-safe path segment" unless admin_path.match?(/\A[a-zA-Z0-9][a-zA-Z0-9_-]{11,}\z/)

  AdminUser.create!(email_address: admin_email, password: admin_password) unless AdminUser.exists?
end

if !Rails.env.production? && ActiveModel::Type::Boolean.new.cast(ENV.fetch("SEED_DEMO_DATA", false))
  # Demo data is destructive and therefore must be explicitly requested outside production.
  AdminTierChange.delete_all
  Tournament.destroy_all
  Match.destroy_all
  DartSetup.destroy_all
  TrainingSession.destroy_all
  Session.destroy_all
  User.destroy_all

  user = User.create!(
    email_address: "test@example.com",
    password: "password",
    account_tier: "premium"
  )

  match = Match.create!
  player = Player.create!(user: user, match: match, name: "Alice")
  Player.create!(user: user, match: match, name: "Guest")
  match_set = match.match_sets.create!
  leg = match_set.legs.create!(match: match)
  leg.turns.create!(player: player)
end
