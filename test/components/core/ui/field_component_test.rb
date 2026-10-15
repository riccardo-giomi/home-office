require "test_helper"

describe Core::UI::FieldComponent do
  include ViewComponent::TestHelpers

  def builder(user)
    ActionView::Helpers::FormBuilder.new(:example_user, user, vc_test_controller.view_context, {})
  end

  it "connects the label to the input" do
    render_inline(Core::UI::FieldComponent.new(form: builder(ExampleUser.new), attribute: :email_address, label: "Email", as: :email_field))
    assert_selector "label[for=example_user_email_address]", text: "Email"
    assert_selector "input#example_user_email_address[type=email]"
    assert_no_selector "[aria-invalid]"
  end

  it "keeps the label, the input and the hint together inside a namespaced form" do
    form = ActionView::Helpers::FormBuilder.new(:example_user, ExampleUser.new, vc_test_controller.view_context, {namespace: "ns1"})
    render_inline(Core::UI::FieldComponent.new(form:, attribute: :password, label: "Password", as: :password_field, hint: "12 or more"))
    assert_selector "label[for=ns1_example_user_password]"
    assert_selector "input#ns1_example_user_password[aria-describedby='ns1_example_user_password_hint']"
    assert_selector "#ns1_example_user_password_hint"
  end

  it "describes the input by its hint" do
    render_inline(Core::UI::FieldComponent.new(form: builder(ExampleUser.new), attribute: :password, label: "Password", as: :password_field, hint: "12 or more"))
    assert_selector "input#example_user_password[aria-describedby='example_user_password_hint']"
    assert_selector "#example_user_password_hint", text: "12 or more"
  end

  it "marks the input invalid and shows each error with an icon" do
    user = ExampleUser.new(email_address: "")
    user.valid?
    render_inline(Core::UI::FieldComponent.new(form: builder(user), attribute: :email_address, label: "Email", as: :email_field))
    assert_selector "input#example_user_email_address[aria-invalid=true][aria-describedby='example_user_email_address_error']"
    assert_selector "#example_user_email_address_error svg[aria-hidden=true]"
    assert_selector "#example_user_email_address_error", text: /blank/
  end

  it "lists both the hint and the errors in aria-describedby" do
    user = ExampleUser.new(password: "x")
    user.valid?
    render_inline(Core::UI::FieldComponent.new(form: builder(user), attribute: :password, label: "Password", as: :password_field, hint: "12 or more"))
    assert_selector "input#example_user_password[aria-describedby='example_user_password_hint example_user_password_error']"
  end

  it "renders a select from choices" do
    render_inline(Core::UI::FieldComponent.new(form: builder(ExampleUser.new), attribute: :role, label: "Role", as: :select, choices: [["Admin", "admin"], ["User", "user"]]))
    assert_selector "select#example_user_role option", count: 2
  end

  it "puts a check box before its label and text areas get their own class" do
    render_inline(Core::UI::FieldComponent.new(form: builder(ExampleUser.new), attribute: :email_address, label: "Remember", as: :check_box))
    assert_selector "input.checkbox[type=checkbox]#example_user_email_address + label[for=example_user_email_address]", text: "Remember"
    render_inline(Core::UI::FieldComponent.new(form: builder(ExampleUser.new), attribute: :email_address, label: "Notes", as: :text_area))
    assert_selector "textarea.textarea"
  end
end
