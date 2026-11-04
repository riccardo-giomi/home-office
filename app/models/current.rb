class Current < ActiveSupport::CurrentAttributes
  attribute :session, :first_weekday, :counts, :overview_users
  delegate :user, to: :session, allow_nil: true
end
