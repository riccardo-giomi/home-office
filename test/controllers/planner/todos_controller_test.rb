require "test_helper"
require_relative "shared_item_pages"

class Planner::TodosControllerTest < ActionDispatch::IntegrationTest
  include SharedItemPages

  let(:item_class) { Planner::Todo }
  let(:kind) { "todo" }
  let(:sample) { planner_items(:water_plants_todo) }
  let(:foreign) { planner_items(:other_users_todo) }

  def default_back(_todo) = planner_todos_path

  describe "what only todos have" do
    before { sign_in_as admin }

    it "asks for no day and no times" do
      get new_planner_todo_path
      assert_select "input[name='planner_todo[title]']"
      assert_select "select[name='planner_todo[priority]']"
      assert_select "textarea[name='planner_todo[notes]']"
      assert_select "input[type=date], input[type=time]", 0
    end

    it "ignores a day or times sent anyway" do
      post planner_todos_path, params: {planner_todo: {title: "Sneaky", day: "2026-10-09", start_time: "09:00", end_time: "10:00"}}
      todo = Planner::Todo.order(:id).last
      assert_equal "Sneaky", todo.title
      assert_nil todo.day
      assert_nil todo.starts_at
    end

    it "has no when row, even for a todo that holds a day from an earlier life as a task" do
      sample.update_columns(day: Date.new(2026, 10, 7))
      get planner_todo_path(sample)
      assert_select "dt", text: "When", count: 0
    end

    it "offers no state change, and refuses one made by hand" do
      get planner_todo_path(sample)
      assert_select "form[action='#{planner_item_state_path(sample)}']", 0
      patch planner_item_state_path(sample), params: {state: "abandoned"}
      assert_equal "active", sample.reload.state
      assert_equal "That change is not possible.", flash[:alert]
    end

    it "shows the done checkbox and ticks in place" do
      get planner_todo_path(sample)
      assert_select "input[type=checkbox][aria-label='Done: Water the plants']", 1
      patch planner_item_completion_path(sample), params: {done: "1"}
      assert sample.reload.done?
    end

    it "names the todos page as the way back" do
      get planner_todo_path(sample)
      assert_select "a", text: "Back to todos"
    end

    it "puts a new urgent todo at the top and a normal one at the bottom" do
      post planner_todos_path, params: {planner_todo: {title: "Fire", priority: "urgent"}}
      post planner_todos_path, params: {planner_todo: {title: "Later"}}
      titles = Planner::Todo.owned_by(admin).in_order.map(&:title)
      assert_equal %w[Fire Later], [titles.first, titles.last]
    end
  end

  describe "the todos page" do
    it "sends anonymous visitors to sign in" do
      get planner_todos_path
      assert_redirected_to new_session_path
    end

    describe "signed in" do
      before { sign_in_as admin }

      it "lists the user's todos in their own order, and no one else's" do
        get planner_todos_path
        assert_response :success
        assert_select "title", "Todos | Home Office"
        assert_select "h1", "Todos"
        assert_equal ["Water the plants", "Call mom", "Finish the book Done", "Renew the license"], css_select("main ol > li a").map { |link| link.text.strip }
        assert_no_match(/Someone else/, response.body)
      end

      it "follows a move: the next one is the next in line" do
        planner_items(:renew_license_todo).move(:top)
        get planner_todos_path
        assert_equal "Renew the license", css_select("main ol > li a").first.text.strip
      end

      it "marks priority for a reader and a done todo as done, with no time line" do
        get planner_todos_path
        assert_select "li", text: /Call mom/ do
          assert_select "span.badge[aria-label='High priority']"
        end
        assert_select "li", text: /Renew the license/ do
          assert_select "span.badge[aria-label='Low priority']"
        end
        assert_select "li", text: /Finish the book/ do
          assert_select "s", text: "Finish the book"
        end
        assert_no_match(/All day/, css_select("main").text)
      end

      it "has a tick box on each todo and a way to add one" do
        get planner_todos_path
        assert_select "main ol input[type=checkbox]", 4
        assert_select "a[href^='#{new_planner_todo_path}']", text: "New todo"
      end

      it "highlights the todo that was just moved, once" do
        patch planner_todo_position_path(planner_items(:call_mom_todo)), params: {move: "top"}
        follow_redirect!
        assert_select "li[data-controller=highlight]", 1
        assert_select "li[data-controller=highlight]", text: /Call mom/
        get planner_todos_path
        assert_select "li[data-controller=highlight]", 0
      end

      it "says so when there are none" do
        Planner::Todo.owned_by(admin).delete_all
        get planner_todos_path
        assert_select "main", text: /No todos\. Add the first one\./
        assert_select "ol", 0
      end

      it "opens a todo in the dialog, and goes back to this page from it" do
        get planner_todos_path
        assert_select "li a[data-turbo-frame='item-dialog-frame'][href*='back=%2Fplanner%2Ftodos']", text: "Call mom"
      end
    end
  end

  it "is the last entry of the Planner group of the sidebar" do
    sign_in_as admin
    get root_path
    links = css_select("nav#sidebar a").map { |link| link.xpath("text()").text.squish }
    assert_equal ["Schedule", "Todos", "Users"], links.values_at(links.index("Todos") - 1, links.index("Todos"), links.index("Todos") + 1)
  end

  describe "in Italian" do
    before do
      admin.update!(locale: "it")
      sign_in_as admin
    end

    it "calls the list and the sidebar entry Da fare, and says empty without a plural" do
      get planner_todos_path
      assert_select "h1", "Da fare"
      assert_select "nav#sidebar a", text: "Da fare"
      Planner::Todo.owned_by(admin).delete_all
      get planner_todos_path
      assert_select "main", text: /La lista è vuota\. Aggiungi il primo\./
    end

    it "speaks of the todo as a masculine noun on its own pages" do
      get planner_todo_path(planner_items(:water_plants_todo))
      assert_select "title", "Da fare: Water the plants | Home Office"
      assert_select "a", text: "Modifica da fare"
    end

    it "names the priority in full for a reader" do
      get planner_todos_path
      assert_select "span.badge[aria-label='Priorità alta']"
      assert_select "span.badge[aria-label='Priorità bassa']"
    end
  end
end
