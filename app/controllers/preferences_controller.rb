class PreferencesController < ApplicationController
  before_action :set_user

  def edit
  end

  def update
    if @user.update(preferences_params)
      redirect_to edit_preferences_path, notice: confirmation_in_new_language
    else
      render :edit, status: :unprocessable_content
    end
  end

  private

  # A separate copy: a rejected value must not stay on Current.user, which the layout and helpers read
  def set_user
    @user = User.find(Current.user.id)
  end

  # Only the preference columns: never email, role or password through this page
  def preferences_params
    params.expect(user: [:locale, :date_format, :first_weekday, :time_format, :time_zone, :theme])
  end

  # The redirect renders in the language just chosen, so the notice must be written in it
  def confirmation_in_new_language
    locale = Core::EffectivePreferences.new(user: @user, accept_language: request.headers["Accept-Language"]).locale
    I18n.with_locale(locale) { t("preferences.update.updated") }
  end
end
