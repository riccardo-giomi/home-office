class ApplicationController < ActionController::Base
  include Authentication
  include RequestPreferences
  # Keep under RequestPreferences so that the timezone is set correctly.
  include Core::CatchUp

  helper_method :current_selection

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  private

  # The records set aside to link, for the bar in the layout and the Links
  # sections.
  def current_selection = @current_selection ||= Core::Selection.new(session, Current.user)
end
