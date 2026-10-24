module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :current_user

    def connect
      set_current_user || reject_unauthorized_connection
    end

    private

    def set_current_user
      # `includes` required by strict_loading
      session = Session.includes(:user).find_by(id: cookies.signed[:session_id])
      # The same rule as the controllers: a deactivated user's session is no
      # session.
      self.current_user = session.user if session&.user&.active?
    end
  end
end
