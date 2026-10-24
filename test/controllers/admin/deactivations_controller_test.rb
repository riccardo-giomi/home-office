require "test_helper"

class Admin::DeactivationsControllerTest < ActionDispatch::IntegrationTest
  before { users(:admin).update!(locale: "en") }

  it "sends anonymous visitors to sign in" do
    post admin_user_deactivation_path(users(:member))
    assert_redirected_to new_session_path
    assert_predicate users(:member).reload, :active?
    delete admin_user_deactivation_path(users(:retired))
    assert_redirected_to new_session_path
    assert_predicate users(:retired).reload, :deactivated?
  end

  it "keeps regular users out" do
    sign_in_as users(:member)
    post admin_user_deactivation_path(users(:other_admin))
    assert_redirected_to root_path
    assert_predicate users(:other_admin).reload, :active?
    delete admin_user_deactivation_path(users(:retired))
    assert_redirected_to root_path
    assert_predicate users(:retired).reload, :deactivated?
  end

  describe "as an admin" do
    before { sign_in_as users(:admin) }

    it "deactivates a user, ends their sessions and says so" do
      member = users(:member)
      member.sessions.create!
      post admin_user_deactivation_path(member)
      assert_redirected_to admin_users_path
      assert_equal "member@example.com deactivated.", flash[:notice]
      assert_predicate member.reload, :deactivated?
      assert_equal 0, member.sessions.count
    end

    it "reactivates a user" do
      delete admin_user_deactivation_path(users(:retired))
      assert_redirected_to admin_users_path
      assert_equal "retired@example.com reactivated.", flash[:notice]
      assert_predicate users(:retired).reload, :active?
    end

    it "says so when the user is already active, instead of reactivating again" do
      delete admin_user_deactivation_path(users(:member))
      assert_redirected_to admin_users_path
      assert_equal "This user is not deactivated.", flash[:alert]
    end

    it "refuses to deactivate oneself, and changes nothing" do
      post admin_user_deactivation_path(users(:admin))
      assert_redirected_to admin_users_path
      assert_equal "You cannot deactivate yourself.", flash[:alert]
      assert_predicate users(:admin).reload, :active?
      assert_equal 1, users(:admin).sessions.count
    end

    it "refuses an already deactivated user and a missing one" do
      post admin_user_deactivation_path(users(:retired))
      assert_redirected_to admin_users_path
      assert_match(/already/, flash[:alert])
      post admin_user_deactivation_path(user_id: 0)
      assert_response :not_found
    end

    it "says in Italian" do
      users(:admin).update!(locale: "it")
      post admin_user_deactivation_path(users(:member))
      assert_equal "member@example.com disattivato.", flash[:notice]
    end
  end
end
