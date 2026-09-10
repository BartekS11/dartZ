class AdminTierOverride
  class NoChange < StandardError; end
  class ReasonRequired < StandardError; end

  TIER_RANK = { "free" => 0, "premium" => 1, "pro" => 2 }.freeze

  def self.call(...)
    new(...).call
  end

  def initialize(user:, admin_user:, override:, reason: nil)
    @user = user
    @admin_user = admin_user
    @override = override.presence
    @reason = reason.to_s.strip.presence
  end

  def call
    validate_override!

    User.transaction do
      user.lock!
      previous_override = user.manual_tier_override
      previous_effective = user.effective_account_tier
      new_effective = override || user.account_tier

      raise NoChange, "Tier override did not change" if previous_override == override
      if TIER_RANK.fetch(new_effective) < TIER_RANK.fetch(previous_effective) && reason.blank?
        raise ReasonRequired, "A reason is required when downgrading access"
      end

      user.update!(manual_tier_override: override)
      AdminTierChange.create!(
        admin_user: admin_user,
        user: user,
        action: override ? "set" : "clear",
        managed_tier: user.account_tier,
        previous_override: previous_override,
        new_override: override,
        previous_effective_tier: previous_effective,
        new_effective_tier: new_effective,
        reason: reason
      )
    end

    user
  end

  private

  attr_reader :user, :admin_user, :override, :reason

  def validate_override!
    return if override.nil? || User::ACCOUNT_TIERS.include?(override)

    raise ArgumentError, "Invalid tier override"
  end
end
