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

  describe "the shape of the pages" do
    before { sign_in_as users(:admin) }

    it "has New user as the page's main action in the toolbar under the heading" do
      get admin_users_path
      assert_select "h1 + div.justify-between a.btn.btn-primary[href='#{new_admin_user_path}']", text: "New user"
    end

    it "puts the way back right under the heading of the new and edit pages, not under the form" do
      [new_admin_user_path, edit_admin_user_path(users(:member))].each do |path|
        get path
        assert_select "h1 + p a[href='#{admin_users_path}']", text: "Back to users"
        assert_select "main form#user-form a", count: 0
      end
    end

    it "keeps Save outside the form element, in the actions row at the end of the page" do
      [new_admin_user_path, edit_admin_user_path(users(:member))].each do |path|
        get path
        assert_select "form#user-form button[type=submit]", count: 0
        assert_select "div.sm\\:justify-between > button.btn-primary[type=submit][form=user-form]", 1
      end
    end
  end

  describe "deleting a user for good" do
    before { sign_in_as users(:admin) }

    def with_hard_delete(on)
      saved = Rails.configuration.x.hard_delete_users
      Rails.configuration.x.hard_delete_users = on
      yield
    ensure
      Rails.configuration.x.hard_delete_users = saved
    end

    it "is off unless the option is set: no button, and the route refuses an admin posting by hand" do
      with_hard_delete(false) do
        get admin_users_path
        assert_select "button", text: /Delete/, count: 0
        assert_no_difference "User.count" do
          delete admin_user_path(users(:retired))
        end
        assert_response :not_found
      end
    end

    it "offers Delete only on deactivated users, with a confirmation that names the user and the data" do
      with_hard_delete(true) do
        get admin_users_path
        assert_select "dialog#delete-user-#{users(:retired).id} p", text: /retired@example.com.*all (their|its) data/i
        assert_select "dialog#delete-user-#{users(:retired).id} form[action='#{admin_user_path(users(:retired))}']"
        assert_select "dialog#delete-user-#{users(:member).id}", 0
        assert_select "dialog#delete-user-#{users(:admin).id}", 0
      end
    end

    it "deletes a deactivated user and all the data of that user" do
      with_hard_delete(true) do
        retired = users(:retired)
        Planner::Todo.create!(user: retired, title: "Theirs")
        assert_difference "User.count", -1 do
          delete admin_user_path(retired)
        end
        assert_redirected_to admin_users_path
        assert_equal "retired@example.com deleted for good.", flash[:notice]
        assert_equal 0, Planner::Item.where(user_id: retired.id).count
      end
    end

    it "refuses an active user, oneself and an unknown one" do
      with_hard_delete(true) do
        assert_no_difference "User.count" do
          delete admin_user_path(users(:member))
          assert_redirected_to admin_users_path
          assert_equal "Deactivate this user before deleting the account.", flash[:alert]
          delete admin_user_path(users(:admin))
          assert_redirected_to admin_users_path
        end
        delete admin_user_path(id: 0)
        assert_response :not_found
      end
    end

    it "keeps regular users and visitors out" do
      with_hard_delete(true) do
        sign_in_as users(:member)
        assert_no_difference "User.count" do
          delete admin_user_path(users(:retired))
        end
        assert_redirected_to root_path
        sign_out
        delete admin_user_path(users(:retired))
        assert_redirected_to new_session_path
      end
    end
  end
end
