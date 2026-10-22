require "test_helper"

class Planner::PositionsControllerTest < ActionDispatch::IntegrationTest
  let(:admin) { users(:admin) }
  let(:water) { planner_items(:water_plants_todo) }
  let(:mom) { planner_items(:call_mom_todo) }
  let(:book) { planner_items(:read_book_todo) }
  let(:license) { planner_items(:renew_license_todo) }

  def order = Planner::Todo.owned_by(admin).in_order.map(&:title)

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
end
