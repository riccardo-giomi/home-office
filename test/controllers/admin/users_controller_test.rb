require "test_helper"

class Admin::UsersControllerTest < ActionDispatch::IntegrationTest
  def valid_params(**overrides)
    {user: {email_address: "new@example.com", role: "user", password: TEST_PASSWORD, password_confirmation: TEST_PASSWORD}.merge(overrides)}
  end

  it "sends anonymous visitors to sign in" do
    get admin_users_path
    assert_redirected_to new_session_path
    assert_no_difference "User.count" do
      post admin_users_path, params: valid_params
    end
    assert_redirected_to new_session_path
  end

  it "keeps regular users out of every admin page and action" do
    sign_in_as users(:member)
    get admin_users_path
    assert_redirected_to root_path
    assert_equal I18n.t("admin.forbidden"), flash[:alert]
    get new_admin_user_path
    assert_redirected_to root_path
    get edit_admin_user_path(users(:admin))
    assert_redirected_to root_path
    assert_no_difference "User.count" do
      post admin_users_path, params: valid_params
    end
    patch admin_user_path(users(:admin)), params: {user: {email_address: "taken-over@example.com"}}
    assert_equal "admin@example.com", users(:admin).reload.email_address
  end

  it "does not let a regular user make themself an administrator" do
    sign_in_as users(:member)
    patch admin_user_path(users(:member)), params: {user: {role: "admin"}}
    assert_equal "user", users(:member).reload.role
  end

  it "returns to a requested admin page after signing in" do
    get admin_users_path
    post session_path, params: {email_address: users(:admin).email_address, password: TEST_PASSWORD}
    assert_redirected_to admin_users_url
  end

  it "does not remember a request that is not GET" do
    post admin_users_path, params: valid_params
    post session_path, params: {email_address: users(:admin).email_address, password: TEST_PASSWORD}
    assert_redirected_to root_url
  end

  describe "as an admin" do
    before { sign_in_as users(:admin) }

    it "lists users" do
      get admin_users_path
      assert_response :success
      assert_select "title", "#{I18n.t("admin.users.index.title")} | Home Office"
      assert_select "td", text: users(:member).email_address
    end

    it "only offers to keep the password on the edit form" do
      get new_admin_user_path
      assert_select "#user_password_hint", text: /keep/, count: 0
      get edit_admin_user_path(users(:member))
      assert_select "#user_password_hint", text: /keep/
    end

    it "creates a user who can then sign in" do
      assert_difference "User.count", 1 do
        post admin_users_path, params: valid_params
      end
      assert_redirected_to admin_users_path
      assert_equal "user", User.find_by!(email_address: "new@example.com").role
      assert User.authenticate_by(email_address: "new@example.com", password: TEST_PASSWORD)
    end

    it "shows an error summary for an invalid user" do
      assert_no_difference "User.count" do
        post admin_users_path, params: valid_params(password: "short", password_confirmation: "short")
      end
      assert_response :unprocessable_content
      assert_select "#error-summary a[href='#user_password']"
    end

    it "keeps the password when it is left blank" do
      member = users(:member)
      digest = member.password_digest
      patch admin_user_path(member), params: {user: {email_address: member.email_address, role: "user", password: "", password_confirmation: ""}}
      assert_redirected_to admin_users_path
      assert_equal digest, member.reload.password_digest
    end

    it "ends the other sessions of a user whose password changed, not its own" do
      member = users(:member)
      member.sessions.create!
      patch admin_user_path(member), params: {user: {password: "a brand new password", password_confirmation: "a brand new password"}}
      assert_equal 0, member.sessions.count
      get admin_users_path
      assert_response :success

      patch admin_user_path(users(:admin)), params: {user: {password: "another new password", password_confirmation: "another new password"}}
      get admin_users_path
      assert_response :success
    end

    it "refuses to demote the last admin" do
      patch admin_user_path(users(:other_admin)), params: {user: {role: "user"}}
      assert_redirected_to admin_users_path
      patch admin_user_path(users(:admin)), params: {user: {role: "user"}}
      assert_response :unprocessable_content
      assert_equal "admin", users(:admin).reload.role
    end
  end
end
