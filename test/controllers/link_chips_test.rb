require "test_helper"

# The entries of every list and grid show how many links their record has, and
# the full ones have a button to set the record aside to link it
class LinkChipsTest < ActionDispatch::IntegrationTest
  let(:admin) { users(:admin) }

  before do
    admin.update!(time_zone: "Europe/Rome", locale: "en")
    travel_to Time.utc(2026, 10, 7, 12)
    sign_in_as admin
  end

  def chips = css_select("span[role=img][aria-label*=link]")

  it "shows the number of a todo's links on its row" do
    get planner_todos_path
    assert_select "li", text: /Water the plants/ do
      assert_select "span[role=img][aria-label='1 link']"
    end
  end

  it "shows it on the entries of every page and view that lists them" do
    [planner_calendar_path(view: "day", date: "2026-10-07"), planner_calendar_path(view: "week", date: "2026-10-07"), planner_calendar_path(view: "month", date: "2026-10-07"),
      planner_agenda_path(view: "day", date: "2026-10-07"), planner_schedule_path(date: "2026-10-07"), planner_schedule_path(view: "week", date: "2026-10-07")].each do |path|
      get path
      assert chips.any?, "#{path} shows no number of links"
    end
  end

  it "counts only the ends that are not in the trash" do
    dentist = planner_items(:dentist)
    count = Core::LinkIndex.new(dentist.id).ends_of(dentist.id).count { |link_end| !link_end.trashed? }
    get planner_agenda_path(view: "day", date: "2026-10-07")
    assert_select "span[role=img][aria-label='#{count} #{(count == 1) ? "link" : "links"}']"
  end

  it "shows nothing for a record without links" do
    get planner_todos_path
    row = css_select("li").find { |li| li.text.include?("Call mom") }
    assert_empty row.css("span[role=img][aria-label*=link]")
  end

  it "offers each full entry the button that sets it aside, and Unselect once it is selected" do
    get planner_todos_path
    assert_select "form[action='/selection'] button[aria-label='Select Water the plants']"
    post selection_path, params: {entity_id: planner_items(:water_plants_todo).id}
    get planner_todos_path
    assert_select "form[action='/selection'] input[name=_method][value=delete] ~ button[aria-label='Unselect Water the plants']"
  end

  it "offers it on the agenda and on the Schedule's day, in the strip of tasks with no time of their own" do
    get planner_agenda_path(view: "day", date: "2026-10-07")
    assert_select "form[action='/selection'] button[aria-label='Select Dentist']"
    get planner_schedule_path(date: "2026-10-08")
    assert_select "form[action='/selection'] button[aria-label='Select Buy stamps']"
  end

  it "leaves out a box cut to its duration, the week and the month: a clipped button would still take the focus" do
    get planner_schedule_path
    assert_select "a", text: "Pay the rent"
    assert_select "form[action='/selection']", 0
    [planner_schedule_path(view: "week"), planner_calendar_path(view: "week"), planner_calendar_path(view: "month")].each do |path|
      get path
      assert_select "form[action='/selection']", 0, "#{path} has the button"
    end
  end

  it "never counts another user's links" do
    Core::Link.connect(users(:other_admin), core_entities(:other_users_event).id, core_entities(:other_users_todo).id)
    get planner_todos_path
    assert_equal 1, chips.size
  end

  it "reads the links of a whole page in the same few queries, however many there are" do
    base = selects { get planner_todos_path }.size
    todos = Planner::Todo.where(user_id: admin.id).to_a
    40.times { |n| Planner::Todo.create!(user: admin, title: "Many #{n}") }
    all = Planner::Todo.where(user_id: admin.id).to_a
    all.each_cons(2) { |a, b| Core::Link.connect(admin, a.id, b.id) }
    many = selects { get planner_todos_path }.size
    assert_equal base, many, "the page asks #{many} questions with #{all.size} linked todos and #{base} with #{todos.size}"
  end
end
