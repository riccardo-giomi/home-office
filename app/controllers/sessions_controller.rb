class SessionsController < ApplicationController
  include Core::ClientAddress

  allow_unauthenticated_access only: %i[new create]
  rate_limit to: 10, within: 3.minutes, by: :client_address, only: :create, with: -> { redirect_to new_session_path, alert: t("sessions.rate_limited") }

  def new
  end

  def create
    # A deactivated user gets the answer a wrong password gets: nothing says the
    # account exists.
    if (user = User.authenticate_by(params.permit(:email_address, :password))) && user.active?
      start_new_session_for user
      redirect_to after_authentication_url
    else
      redirect_to new_session_path, alert: t("sessions.invalid")
    end
  end

  def destroy
    terminate_session
    redirect_to new_session_path, status: :see_other
  end
end
