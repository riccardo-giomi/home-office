require "test_helper"

class TrashesControllerTest < ActionDispatch::IntegrationTest
  before { users(:admin).update!(locale: "en") }

  it "sends anonymous visitors to sign in" do
    get trash_path
    assert_redirected_to new_session_path
  end

  it "shows a card for the Planner with what is in its trash for each kind, zeros too" do
    sign_in_as users(:admin)
    get trash_path
    assert_response :success
    assert_select "title", "Trash | Home Office"
    assert_select "ul[aria-label='Trash by module'] > li", 1
    assert_select "a[href='#{planner_trash_path}']", text: /Planner/ do
      assert_select "span", text: "2 events"
      assert_select "span", text: "1 task"
      assert_select "span", text: "1 todo"
    end
  end

  it "keeps zeros visible and never counts another user's trash" do
    sign_in_as users(:member)
    get trash_path
    assert_select "a[href='#{planner_trash_path}']" do
      assert_select "span", text: "0 events"
      assert_select "span", text: "0 tasks"
      assert_select "span", text: "0 todos"
    end
  end

  it "speaks Italian" do
    users(:admin).update!(locale: "it")
    sign_in_as users(:admin)
    get trash_path
    assert_select "title", "Cestino | Home Office"
    assert_select "a span", text: "2 eventi"
  end
end
