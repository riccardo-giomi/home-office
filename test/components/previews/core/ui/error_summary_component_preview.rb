class Core::UI::ErrorSummaryComponentPreview < ViewComponent::Preview
  def invalid_user
    user = ExampleUser.new(email_address: "", password: "short")
    user.valid?
    # Not autofocused and with its own id: the Theme page shows many previews at once
    render Core::UI::ErrorSummaryComponent.new(record: user, id: "error-summary-#{SecureRandom.hex(3)}", autofocus: false)
  end
end
