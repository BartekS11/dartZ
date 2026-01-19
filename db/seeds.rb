User.destroy_all
Match.destroy_all
Player.destroy_all
Leg.destroy_all
Turn.destroy_all

user = User.create!(
  email_address: "test@example.com",
  password: "password"
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

leg = match.legs.create!

leg.turns.create!(
  player: player
)
