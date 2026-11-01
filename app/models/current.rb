class Current < ActiveSupport::CurrentAttributes
  attribute :session, :counts
  delegate :user, to: :session, allow_nil: true
end
