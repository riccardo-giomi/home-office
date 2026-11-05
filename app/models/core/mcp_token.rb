# What an agent presents to the MCP endpoint, as `Authorization: Bearer <token>`.
#
# Only the SHA-256 of the token is stored. A token is 32 random bytes, so it is
# no password and needs no slow hash, and a leaked table gives no way in. The
# plain text exists once, on the token that was just generated.
#
# `read_only` is a setting chosen when the token is made (0 or 1): such a token
# is given only the tools that change nothing.
class Core::McpToken < ApplicationRecord
  PREFIX = "ho_"
  MAX_LENGTH = PREFIX.size + 64

  # A token used a moment ago is not written again: a busy agent would write on
  # every read.
  TOUCH_EVERY = 1.minute

  belongs_to :user
  attr_accessor :plain

  normalizes :name, with: ->(name) { name.strip }
  validates :name, presence: true, length: {maximum: 60}, uniqueness: {scope: :user_id}
  validates :read_only, inclusion: {in: [0, 1]}

  def self.digest(plain) = Digest::SHA256.hexdigest(plain)

  # Makes a token and returns it, saved if it is valid (see `persisted?`).
  #
  # `plain` is the only time the text can be read.
  def self.generate_for(user, name:, read_only:)
    plain = "#{PREFIX}#{SecureRandom.hex(32)}"
    read_only = ActiveModel::Type::Boolean.new.cast(read_only) ? 1 : 0
    new(user:, name:, read_only:, token_digest: digest(plain)).tap do |token|
      token.plain = plain
      begin
        token.save
      rescue ActiveRecord::RecordNotUnique
        # The same name was saved a moment ago (a double click): the validation
        # could not see it yet.
        token.errors.add(:name, :taken)
      end
    end
  end

  # Returns the token that the text belongs to, with its user, or nil.
  #
  # It is nil for unknown text, text of another shape and a user who is
  # deactivated.
  def self.authenticate(plain)
    return unless plain.is_a?(String) && plain.size == MAX_LENGTH && plain.start_with?(PREFIX)

    token = includes(:user).find_by(token_digest: digest(plain))
    token if token&.user&.active?
  end

  def read_only? = read_only == 1

  def touch_last_used(now = Time.current)
    update_columns(last_used_at: now) if last_used_at.nil? || last_used_at <= now - TOUCH_EVERY
  end
end
