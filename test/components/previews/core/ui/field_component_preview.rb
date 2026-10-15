class Core::UI::FieldComponentPreview < ViewComponent::Preview
  def plain
    render_field(ExampleUser.new, :email_address, label: "Email address", as: :email_field)
  end

  def with_hint
    render_field(ExampleUser.new, :password, label: "Password", as: :password_field, hint: "At least 12 characters")
  end

  def with_error
    user = ExampleUser.new(email_address: "")
    user.valid?
    render_field(user, :email_address, label: "Email address", as: :email_field)
  end

  def select
    render_field(ExampleUser.new, :role, label: "Role", as: :select, choices: [["Administrator", "admin"], ["User", "user"]])
  end

  private

  # A throwaway form builder: previews have no surrounding form, and the namespace keeps ids unique when
  # several examples share one page
  def render_field(record, attribute, **options)
    form = ActionView::Helpers::FormBuilder.new(record.model_name.param_key, record, ActionView::Base.empty, {namespace: SecureRandom.hex(3)})
    render Core::UI::FieldComponent.new(form:, attribute:, **options)
  end
end
