class User < ApplicationRecord
  has_secure_password
  # delete_all: strict loading forbids loading the sessions just to destroy them
  has_many :sessions, dependent: :delete_all
  enum :role, {admin: "admin", user: "user"}, default: :user, validate: true
  normalizes :email_address, with: ->(e) { e.strip.downcase }
end
