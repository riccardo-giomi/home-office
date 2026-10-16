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

  private

  # Application guard only; the database cannot express it
  def keep_an_admin
    return unless role_changed? && role_was == "admin"
    errors.add(:role, :last_admin) unless User.admin.where.not(id: id).exists?
  end
end
