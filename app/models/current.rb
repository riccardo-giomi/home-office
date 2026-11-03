class Current < ActiveSupport::CurrentAttributes
  attribute :session, :first_weekday, :counts
  delegate :user, to: :session, allow_nil: true
end
