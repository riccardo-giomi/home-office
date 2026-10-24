require "test_helper"

class SessionsControllerTest < ActionDispatch::IntegrationTest
  def sign_in(email: users(:admin).email_address, password: TEST_PASSWORD)
    post session_path, params: {email_address: email, password: password}
  end

  it "shows the sign-in form with a translated title" do
    get new_session_path
    assert_response :success
    assert_select "title", "#{I18n.t("sessions.new.title")} | Home Office"
    assert_select "label[for=email_address]"
    assert_select "input#email_address[autocomplete=username]"
    assert_select "input#password[type=password][autocomplete=current-password]"
  end

  it "signs in and returns to the requested page" do
    get root_path
    assert_redirected_to new_session_path
    sign_in
    assert_redirected_to root_url
    assert_equal 1, users(:admin).sessions.count
  end

  it "ignores case and surrounding spaces in the email address" do
    sign_in(email: "  ADMIN@Example.COM ")
    assert_redirected_to root_url
  end

  it "answers a wrong password and an unknown email the same way" do
    sign_in(password: "wrong password here")
    wrong_password = [response.location, flash[:alert]]
    sign_in(email: "nobody@example.com")
    assert_equal wrong_password, [response.location, flash[:alert]]
    assert_equal I18n.t("sessions.invalid"), flash[:alert]
  end

  it "refuses even the correct password after 10 failures" do
    10.times { sign_in(password: "wrong password here") }
    sign_in
    assert_redirected_to new_session_path
    assert_equal I18n.t("sessions.rate_limited"), flash[:alert]
    get root_path
    assert_redirected_to new_session_path
  end

  it "signs out and the old cookie no longer works" do
    sign_in
    follow_redirect!
    assert_select "p", text: /#{users(:admin).email_address}/
    delete session_path
    assert_redirected_to new_session_path
    assert_equal 0, users(:admin).sessions.count
    get root_path
    assert_redirected_to new_session_path
  end

  it "refuses a deactivated user with the same answer as a wrong password" do
    sign_in(email: users(:retired).email_address)
    assert_redirected_to new_session_path
    assert_equal I18n.t("sessions.invalid"), flash[:alert]
    assert_equal 0, users(:retired).sessions.count
  end

  it "signs a user out at the next request once they are deactivated, even with a live cookie" do
    member = users(:member)
    sign_in_as member
    get root_path
    assert_response :success
    member.update_columns(deactivated_at: Time.current)
    get root_path
    assert_redirected_to new_session_path
  end
end
