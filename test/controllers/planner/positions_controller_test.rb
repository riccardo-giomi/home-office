require "test_helper"

class Planner::PositionsControllerTest < ActionDispatch::IntegrationTest
  let(:admin) { users(:admin) }
  let(:water) { planner_items(:water_plants_todo) }
  let(:mom) { planner_items(:call_mom_todo) }
  let(:book) { planner_items(:read_book_todo) }
  let(:license) { planner_items(:renew_license_todo) }

  def order = Planner::Todo.owned_by(admin).kept.in_order.map(&:title)

  before do
    admin.update!(locale: "en")
    sign_in_as admin
  end

  it "sends anonymous visitors to sign in" do
    sign_out
    patch planner_todo_position_path(mom), params: {move: "top"}
    assert_redirected_to new_session_path
  end

  {"up" => ["Call mom", "Water the plants", "Finish the book", "Renew the license"],
   "down" => ["Water the plants", "Finish the book", "Call mom", "Renew the license"],
   "top" => ["Call mom", "Water the plants", "Finish the book", "Renew the license"],
   "bottom" => ["Water the plants", "Finish the book", "Renew the license", "Call mom"]}.each do |move, expected|
    it "moves a todo #{move}, goes back to the list and says where it went" do
      patch planner_todo_position_path(mom), params: {move:}
      assert_redirected_to planner_todos_path
      assert_equal expected, order
      assert_match(/“Call mom” moved to position \d of 4\./, flash[:notice])
      assert_equal mom.id, flash[:moved_id]
    end
  end

  it "says it is already there, and changes nothing, for a move that goes nowhere" do
    patch planner_todo_position_path(water), params: {move: "top"}
    assert_redirected_to planner_todos_path
    assert_equal "“Water the plants” is already there.", flash[:alert]
    assert_equal ["Water the plants", "Call mom", "Finish the book", "Renew the license"], order
  end

  it "says the place among the todos in view, not the stored position, when some are in the trash" do
    planner_items(:read_book_todo).trash
    patch planner_todo_position_path(license), params: {move: "up"}
    assert_equal "“Renew the license” moved to position 2 of 3.", flash[:notice]
  end

  it "refuses a move it does not know" do
    ["banana", "", nil, "TOP"].each do |move|
      patch planner_todo_position_path(mom), params: {move:}
      assert_equal "That move is not possible.", flash[:alert], move.inspect
    end
    assert_equal ["Water the plants", "Call mom", "Finish the book", "Renew the license"], order
  end

  it "does not find someone else's todo, nor an event or task by that route" do
    theirs = planner_items(:other_users_todo)
    patch planner_todo_position_path(theirs), params: {move: "bottom"}
    assert_response :not_found
    patch planner_todo_position_path(planner_items(:pay_rent_task)), params: {move: "bottom"}
    assert_response :not_found
    assert_equal 1, theirs.reload.position
  end

  it "speaks Italian to an Italian user" do
    admin.update!(locale: "it")
    patch planner_todo_position_path(mom), params: {move: "top"}
    assert_match(/«Call mom» spostato in posizione 1 di 4\./, flash[:notice])
  end

  describe "next to another todo, as a drag leaves it" do
    it "puts it after the todo the row now follows" do
      patch planner_todo_position_path(license), params: {after: water.id}
      assert_equal ["Water the plants", "Renew the license", "Call mom", "Finish the book"], order
      assert_equal license.id, flash[:moved_id]
      assert_match(/“Renew the license” moved to position 2 of 4\./, flash[:notice])
    end

    it "puts it before the todo the row now precedes" do
      patch planner_todo_position_path(water), params: {before: book.id}
      assert_equal ["Call mom", "Water the plants", "Finish the book", "Renew the license"], order
    end

    it "refuses a neighbor that is not one of the user's todos, and an event or task, and junk" do
      theirs = planner_items(:other_users_todo)
      [theirs.id, planner_items(:dentist).id, planner_items(:pay_rent_task).id, "junk", 0, ""].each do |id|
        patch planner_todo_position_path(mom), params: {after: id}
        assert_equal "That move is not possible.", flash[:alert], id.inspect
      end
      assert_equal ["Water the plants", "Call mom", "Finish the book", "Renew the license"], order
    end

    it "says it is already there when the neighbor is itself, or the order does not change" do
      patch planner_todo_position_path(mom), params: {after: mom.id}
      assert_equal "“Call mom” is already there.", flash[:alert]
      patch planner_todo_position_path(mom), params: {after: water.id}
      assert_equal "“Call mom” is already there.", flash[:alert]
    end

    it "refuses a request that asks for two things at once, or for none" do
      patch planner_todo_position_path(mom), params: {move: "top", after: license.id}
      assert_equal "That move is not possible.", flash[:alert]
      patch planner_todo_position_path(mom), params: {}
      assert_equal "That move is not possible.", flash[:alert]
      assert_equal ["Water the plants", "Call mom", "Finish the book", "Renew the license"], order
    end

    it "treats an empty drop field as not given, as the list's own form sends it" do
      patch planner_todo_position_path(license), params: {after: water.id, before: ""}
      assert_equal ["Water the plants", "Renew the license", "Call mom", "Finish the book"], order
    end
  end
end
