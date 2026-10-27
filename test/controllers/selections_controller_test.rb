require "test_helper"

class SelectionsControllerTest < ActionDispatch::IntegrationTest
  let(:admin) { users(:admin) }
  let(:dentist) { planner_items(:dentist) }
  let(:holiday) { planner_items(:holiday) }

  before do
    admin.update!(locale: "en")
    sign_in_as admin
  end

  def selected_titles
    get planner_todos_path
    css_select("[aria-label='Selected records'] a").map(&:text)
  end

  it "selects a record, and shows it in the header on every page" do
    post selection_path, params: {entity_id: dentist.id}
    assert_redirected_to root_path
    _(selected_titles).must_equal ["Dentist"]
  end

  it "selects at most two, and says so for a third" do
    post selection_path, params: {entity_id: dentist.id}
    post selection_path, params: {entity_id: holiday.id}
    post selection_path, params: {entity_id: planner_items(:rent_paid).id}
    assert_equal "Two records are already selected. Unselect one first.", flash[:alert]
    _(selected_titles).must_equal ["Dentist", "Bank holiday"]
  end

  it "unselects one, or clears all" do
    post selection_path, params: {entity_id: dentist.id}
    post selection_path, params: {entity_id: holiday.id}
    delete selection_path, params: {entity_id: dentist.id}
    _(selected_titles).must_equal ["Bank holiday"]
    delete selection_path
    _(selected_titles).must_equal []
  end

  it "answers 404 for another user's record, a trashed one, or none, and selects nothing" do
    post selection_path, params: {entity_id: planner_items(:other_users_event).id}
    assert_response :not_found
    post selection_path, params: {entity_id: planner_items(:trashed_event).id}
    assert_response :not_found
    post selection_path, params: {entity_id: 0}
    assert_response :not_found
    _(selected_titles).must_equal []
  end

  it "forgets a selected record once it is in the trash" do
    post selection_path, params: {entity_id: holiday.id}
    holiday.trash
    _(selected_titles).must_equal []
  end

  it "from a Links section, redraws it (the buttons change) and refreshes the page behind" do
    post selection_path, params: {entity_id: dentist.id, in_section: "1"}, as: :turbo_stream
    assert_select "turbo-stream[action=replace][target=links-section]", 1
    assert_select "turbo-stream[action=refresh]:not([request-id])", 1
    assert_select "turbo-stream[action=replace] template button", text: "Unselect this record"
  end

  it "from a row, only refreshes the page" do
    post selection_path, params: {entity_id: dentist.id}, as: :turbo_stream
    assert_select "turbo-stream[action=refresh]", 1
    assert_select "turbo-stream[action=replace]", 0
  end

  it "wants a signed-in user" do
    delete session_path
    post selection_path, params: {entity_id: dentist.id}
    assert_redirected_to new_session_path
  end
end
