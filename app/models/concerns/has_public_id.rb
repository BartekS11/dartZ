module HasPublicId
  extend ActiveSupport::Concern

  PUBLIC_ID_RANDOM_LENGTH = 16
  PUBLIC_ID_RANDOM_ALPHABET = [ *"0".."9", *"A".."Z", *"a".."z" ].freeze

  included do
    before_validation :ensure_public_id, on: :create

    validates :public_id,
      presence: true,
      uniqueness: true,
      format: { with: ->(record) { record.class.public_id_format } }
  end

  class_methods do
    def public_id_prefix(value = nil)
      if value
        @public_id_prefix = value
      else
        @public_id_prefix || raise("public_id_prefix missing for #{name}")
      end
    end

    def public_id_format
      /\A#{Regexp.escape(public_id_prefix)}[0-9A-Za-z]{#{PUBLIC_ID_RANDOM_LENGTH}}\z/
    end

    def find_by_public_id!(value)
      value = value.to_s
      raise ActiveRecord::RecordNotFound, "Couldn't find #{name}" unless value.match?(public_id_format)

      find_by!(public_id: value)
    end
  end

  def to_param
    self[:public_id]
  end

  private

  def ensure_public_id
    return if self[:public_id].present?

    loop do
      candidate_public_id = "#{self.class.public_id_prefix}#{random_public_id_suffix}"
      self[:public_id] = candidate_public_id
      break unless self.class.exists?(public_id: candidate_public_id)
    end
  end

  def random_public_id_suffix
    Array.new(PUBLIC_ID_RANDOM_LENGTH) { PUBLIC_ID_RANDOM_ALPHABET[SecureRandom.random_number(PUBLIC_ID_RANDOM_ALPHABET.length)] }.join
  end
end
