class Core::Setup::AdminStep
  PASSWORD_VARIABLE = "HOME_OFFICE_ADMIN_PASSWORD"

  def title = I18n.t("core.setup.admin.title")

  def call(context)
    return I18n.t("core.setup.admin.skipped") if User.admin.exists?

    user = User.create!(email_address: email_from(context), password: password_from(context), role: :admin)
    I18n.t("core.setup.admin.created", email: user.email_address)
  rescue ActiveRecord::RecordInvalid => error
    raise Core::Setup::Error, error.record.errors.full_messages.to_sentence
  end

  private

  def email_from(context)
    context.email.presence || begin
      context.output.print I18n.t("core.setup.admin.email_prompt")
      context.input.gets.to_s.strip
    end
  end

  def password_from(context)
    context.env[PASSWORD_VARIABLE].presence || typed_password(context)
  end

  # A typed password is asked twice: nobody sees what they typed
  def typed_password(context)
    password = context.password_reader.call(I18n.t("core.setup.admin.password_prompt")).presence ||
      raise(Core::Setup::Error, I18n.t("core.setup.admin.no_password"))
    confirmation = context.password_reader.call(I18n.t("core.setup.admin.password_confirm_prompt"))
    raise Core::Setup::Error, I18n.t("core.setup.admin.password_mismatch") unless password == confirmation
    password
  end
end
