user = User.find_or_create_by!(email_address: "test@example.com") do |u|
  u.password = "password"
end

player = user.players.find_or_create_by!(name: "Alice")

player.matches.first_or_create!
