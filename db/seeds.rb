user = User.find_or_create_by!(email_address: "test@example.com") do |u|
  u.password = "password"
end

opponent = User.find_or_create_by!(email_address: "opponent@test.com") do |u|
  u.password = "password"
end

match = Match.create!

match.players.create!(user: user, name: "Alice")
match.players.create!(user: opponent, name: "Bob")

match.start_first_leg!
