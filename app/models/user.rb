class User < ApplicationRecord
  has_secure_password
  include Preferences

  # delete_all: strict loading forbids loading the sessions just to destroy them
  has_many :sessions, dependent: :delete_all
  enum :role, {admin: "admin", user: "user"}, default: :user, validate: true
  normalizes :email_address, with: ->(e) { e.strip.downcase }

  validates :email_address, presence: true, uniqueness: true, format: {with: URI::MailTo::EMAIL_REGEXP}
  validates :password, length: {minimum: 12}, allow_nil: true
  validate :keep_an_admin, on: :update

  scope :active, -> { where(deactivated_at: nil) }

  def active? = deactivated_at.nil?

  def deactivated? = !active?

  # Deactivates the user.
  #
  # Ends the sessions and keeps everything else. Answers false, with the reason
  # in errors, when it must not happen.
  def deactivate
    return errors.add(:base, :already_deactivated) && false if deactivated?
    return errors.add(:base, :last_admin_deactivation) && false if last_active_admin?

    transaction do
      update_columns(deactivated_at: Time.current)
      sessions.delete_all
    end
    true
  end

  def reactivate = update_columns(deactivated_at: nil)

  private

  # Whether this is the last active administrator.
  #
  # Application guard only, the database cannot express it. A deactivated
  # administrator cannot take over, so only active ones count.
  def last_active_admin? = admin? && active? && !User.admin.active.where.not(id:).exists?

  def keep_an_admin
    return unless role_changed? && role_was == "admin" && active?
    errors.add(:role, :last_admin) unless User.admin.active.where.not(id:).exists?
  end
end
