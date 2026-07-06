class MatchCreator
  def self.call(...)
    new(...).call
  end

  def initialize(settings:, players:, guest_match: false, guest_id: nil, nickname_user: nil, nickname: nil)
    @settings = settings
    @players = players
    @guest_match = guest_match
    @guest_id = guest_id
    @nickname_user = nickname_user
    @nickname = nickname
  end

  def call
    match = Match.new(@settings.to_h.merge(guest_id: @guest_id))

    ApplicationRecord.transaction do
      match.ensure_guest_token! if @guest_match
      match.save!
      update_nickname!
      create_players!(match)
      match.ensure_match_identifier!
      match.start_first_set!
    end

    match
  end

  private

  def update_nickname!
    return unless @nickname_user && @nickname.present? && @nickname_user.nickname != @nickname

    @nickname_user.update!(nickname: @nickname)
  end

  def create_players!(match)
    @players.each do |player_attributes|
      attrs = player_attributes.dup
      dart_setup = attrs.delete(:dart_setup)
      player = match.players.build(attrs)
      player.assign_dart_setup_snapshot!(dart_setup) if dart_setup
      player.save!
    end
  end
end
