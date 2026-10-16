class ThemesController < ApplicationController
  allow_unauthenticated_access

  def update
    theme = params[:theme].to_s
    return head :unprocessable_content unless User::Preferences::THEMES.include?(theme)

    Current.user&.update!(theme:) if authenticated?
    cookies[:theme] = {value: theme, expires: 1.year, same_site: :lax}
    head :no_content
  end
end
