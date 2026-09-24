require "digest"
require "uri"

class PushSubscription < ApplicationRecord
  include HasPublicId
  public_id_prefix "ps_"

  encrypts :endpoint
  encrypts :p256dh
  encrypts :auth

  belongs_to :user
  has_many :push_deliveries, dependent: :destroy

  before_validation :normalize_endpoint

  validates :endpoint, presence: true, length: { maximum: 2048 }
  validates :endpoint_digest, presence: true, uniqueness: true
  validates :p256dh, :auth, presence: true, length: { maximum: 512 }
  validates :device_label, presence: true, length: { maximum: 80 }
  validates :failure_count, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validate :endpoint_must_use_https

  scope :active, -> { where(revoked_at: nil) }

  def revoke!(error_code: nil)
    update!(revoked_at: Time.current, last_failure_at: Time.current, last_error_code: error_code)
  end

  def record_success!
    update!(last_success_at: Time.current, failure_count: 0, last_error_code: nil)
  end

  def record_failure!(error_code)
    update!(last_failure_at: Time.current, failure_count: failure_count + 1, last_error_code: error_code.to_s.first(100))
  end

  private

  def normalize_endpoint
    self.endpoint = endpoint.to_s.strip
    self.endpoint_digest = Digest::SHA256.hexdigest(endpoint) if endpoint.present?
  end

  def endpoint_must_use_https
    uri = URI.parse(endpoint.to_s)
    errors.add(:endpoint, :invalid) unless uri.is_a?(URI::HTTPS) && uri.host.present? && uri.userinfo.nil?
  rescue URI::InvalidURIError
    errors.add(:endpoint, :invalid)
  end
end
