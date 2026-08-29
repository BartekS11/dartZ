# Destroy records in dependency order so foreign keys do not block reseeding.
Tournament.destroy_all if defined?(Tournament)
Match.destroy_all
DartSetup.destroy_all if defined?(DartSetup)
TrainingSession.destroy_all if defined?(TrainingSession)
Session.destroy_all if defined?(Session)
User.destroy_all

user = User.create!(
  email_address: "test@example.com",
  password: "password",
  account_tier: "premium"
)

match = Match.create!

player = Player.create!(
  user: user,
  match: match,
  name: "Alice"
)

guest = Player.create!(
  user: user,
  match: match,
  name: "Guest"
)

match_set = match.match_sets.create!
leg = match_set.legs.create!(match: match)

leg.turns.create!(
  player: player
)
