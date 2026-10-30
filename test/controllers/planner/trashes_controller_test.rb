require "test_helper"

class Planner::TrashesControllerTest < ActionDispatch::IntegrationTest
  let(:admin) { users(:admin) }

  before do
    admin.update!(locale: "en", time_zone: "UTC", time_format: "24h", date_format: "dmy")
    sign_in_as admin
  end

  it "sends anonymous visitors to sign in" do
    sign_out
    get planner_trash_path
    assert_redirected_to new_session_path
    delete planner_trash_path
    assert_redirected_to new_session_path
    assert_predicate Planner::Item.owned_by(admin).trashed, :any?
  end

  it "lists the trashed items with their kind, and nothing kept or foreign" do
    get planner_trash_path
    assert_response :success
    assert_select "title", "Trash | Home Office"
    assert_select "main ol[aria-label='Trashed items'] > li", 4
    assert_select "li", text: /Thrown away event/
    assert_select "li", text: /Event/
    assert_select "li", text: /Dentist/, count: 0
    assert_select "li", text: /Someone else/, count: 0
  end

  it "shows an event's own day and times on a second line, in its own zone, and the day it was trashed" do
    get planner_trash_path
    assert_select "li#trashed_#{planner_items(:trashed_event).id}" do
      assert_select "time[datetime='2026-10-07']", text: "07/10/2026"
      assert_select "time", text: "15:00"
      assert_select "time", text: "15:30"
      # The day and both times stay together when the line wraps.
      assert_select "span.whitespace-nowrap time", 3
      assert_select "time[datetime^='#{planner_items(:trashed_event).deleted_at.to_date.iso8601}']"
    end
  end

  it "shows a task's day, an all-day event as such, and nothing of the sort for a todo" do
    get planner_trash_path
    assert_select "li#trashed_#{planner_items(:trashed_task).id} time[datetime='2026-09-30']"
    assert_select "li#trashed_#{planner_items(:expired_event).id}", text: /All day/
    assert_select "li#trashed_#{planner_items(:trashed_todo).id} time[datetime='2026-09-30']", 0
    assert_select "li#trashed_#{planner_items(:trashed_todo).id}", text: /Trashed/
  end

  it "offers tabs by kind, each with its count, and marks the current one" do
    get planner_trash_path(type: "event")
    assert_select "ul[aria-label='Show'] a", 4
    assert_select "ul[aria-label='Show'] a[aria-current=true]", text: /Events \(2\)/
    assert_select "ul[aria-label='Show'] a", text: /All \(4\)/
    assert_select "ul[aria-label='Show'] a", text: /Tasks \(1\)/
    assert_select "ul[aria-label='Show'] a", text: /Todos \(1\)/
    assert_select "main ol > li", 2
  end

  it "shows everything for an unknown kind" do
    get planner_trash_path(type: "banana")
    assert_select "main ol > li", 4
    assert_select "ul[aria-label='Show'] a[aria-current=true]", text: /All/
  end

  it "paginates past 25 rows" do
    26.times { |n| Planner::Todo.create!(user: admin, title: "Bulk #{n}").trash }
    get planner_trash_path
    assert_select "main ol > li", 25
    assert_select "nav[aria-label='Pages'] a[aria-current=page]"
    get planner_trash_path(page: 2)
    assert_select "main ol > li", 5
  end

  it "says the trash is empty" do
    Planner::Item.owned_by(admin).trashed.delete_all
    get planner_trash_path
    assert_select "main", text: /The trash is empty/
    assert_select "dialog#empty-trash", 0
  end

  it "empties the whole trash of the user whatever tab is open, and says how many" do
    delete planner_trash_path, params: {type: "task"}
    assert_redirected_to planner_trash_path
    assert_equal "Trash emptied: 4 items deleted for good.", flash[:notice]
    assert_equal 0, Planner::Item.owned_by(admin).trashed.count
    assert_equal 1, Planner::Item.owned_by(users(:other_admin)).trashed.count
  end

  it "asks for a confirmation that says how many go" do
    get planner_trash_path
    assert_select "dialog#empty-trash p", text: /4 items/
    assert_select "dialog#empty-trash form[action='#{planner_trash_path}'] input[name=_method][value=delete]"
  end

  it "speaks Italian" do
    admin.update!(locale: "it")
    get planner_trash_path
    assert_select "title", "Cestino | Home Office"
    assert_select "ul a", text: /Eventi \(2\)/
  end

  it "goes to the last page for a page number that no longer exists, keeping the tab" do
    get planner_trash_path(page: 9, type: "event")
    assert_redirected_to planner_trash_path(type: "event", page: 1)
    follow_redirect!
    assert_select "main ol > li", 2
    assert_select "ul[aria-label='Show'] a[aria-current=true]", text: /Events/
  end

  it "ends on the empty trash, not in a loop, for any page number" do
    Planner::Item.owned_by(admin).trashed.delete_all
    get planner_trash_path(page: 5)
    assert_redirected_to planner_trash_path(page: 1)
    follow_redirect!
    assert_response :success
    assert_select "main", text: /The trash is empty/
  end

  describe "series" do
    let(:member) { users(:member) }
    let(:gym) do
      Planner::Series.create!(user: member, title: "Gym", starts_on: Date.new(2026, 10, 5), time_zone: "UTC", rrule: "FREQ=WEEKLY;INTERVAL=2;BYDAY=MO", start_time: "18:00", duration_minutes: 60, tracks_done: 1)
    end

    before do
      member.update!(locale: "en", time_zone: "UTC", time_format: "24h", date_format: "dmy")
      sign_in_as member
      gym.materialize(Date.new(2026, 10, 19))
      Planner::Recurrence::Delete.new(series: gym, item: gym.occurrence(Date.new(2026, 10, 5)), scope: "all").call
      Planner::Event.create!(user: member, title: "Alone", day: Date.new(2026, 10, 7)).trash
    end

    it "lists a series as one row, with its rule in words, and not the events trashed with it" do
      get planner_trash_path
      assert_response :success
      assert_select "main ol > li", 2
      assert_select "li#trashed_series_#{gym.id}", text: /Series: Gym \(every 2 weeks on Mon\)/
      assert_select "li", text: /Alone/
      assert_select "li", text: /Gym/, count: 1
    end

    it "offers to restore it, naming it for a reader" do
      get planner_trash_path
      assert_select "li#trashed_series_#{gym.id} form[action='#{planner_series_restoration_path(gym)}'] button", text: /Restore\s*Gym/
    end

    it "counts it in all and in events, and lists it under those tabs only" do
      get planner_trash_path(type: "event")
      assert_select "ul[aria-label='Show'] a", text: /All \(2\)/
      assert_select "ul[aria-label='Show'] a[aria-current=true]", text: /Events \(2\)/
      assert_select "li#trashed_series_#{gym.id}"
      get planner_trash_path(type: "task")
      assert_select "li#trashed_series_#{gym.id}", 0
      get planner_trash_path(type: "todo")
      assert_select "li#trashed_series_#{gym.id}", 0
    end

    it "shows it on the first page only, so a long list does not repeat it" do
      30.times { |n| Planner::Event.create!(user: member, title: "Extra #{n}", day: Date.new(2026, 10, 7)).trash }
      get planner_trash_path
      assert_select "li#trashed_series_#{gym.id}", 1
      get planner_trash_path(page: 2)
      assert_select "li#trashed_series_#{gym.id}", 0
    end

    it "is emptied with the rest, and the notice counts it" do
      delete planner_trash_path
      assert_equal "Trash emptied: 2 items deleted for good.", flash[:notice]
      assert_equal 0, Planner::Series.where(user_id: member.id).count
    end
  end
end
