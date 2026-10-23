require "test_helper"

describe Core::UI::ReorderableListComponent do
  include ViewComponent::TestHelpers

  def labels(title) = {group: "Move #{title}", up: "Move up: #{title}", down: "Move down: #{title}", top: "Move to top: #{title}", bottom: "Move to bottom: #{title}"}

  def list(*titles, highlight: nil)
    render_inline(Core::UI::ReorderableListComponent.new(label: "Todo list", empty_text: "Nothing to do.")) do |component|
      titles.each_with_index do |title, index|
        component.with_row(id: "todo_#{index}", item_id: index + 10, move_url: "/planner/todos/#{index}/position", first: index.zero?, last: index == titles.size - 1,
          labels: labels(title), highlight: highlight == index) { title }
      end
    end
  end

  it "is a labeled ordered list with a row for each item" do
    list("A", "B", "C")
    assert_selector "ol[aria-label='Todo list'] > li", count: 3
    assert_selector "li#todo_1", text: "B"
  end

  it "gives each row four buttons named after the row, in a labeled group" do
    list("A", "B", "C")
    assert_selector "li#todo_1 [role=group][aria-label='Move B']"
    ["Move up: B", "Move down: B", "Move to top: B", "Move to bottom: B"].each { |name| assert_selector "li#todo_1 button[aria-label='#{name}']" }
  end

  it "makes a move a PATCH to the row's own address, one value for each button" do
    list("A", "B", "C")
    assert_selector "li#todo_1 form[action='/planner/todos/1/position'] input[name=_method][value=patch]", visible: :all
    %w[up down top bottom].each { |move| assert_selector "li#todo_1 button[type=submit][name=move][value=#{move}]" }
  end

  it "keeps the buttons that cannot move the row, but disabled to assistive technology and inert, so focus has somewhere to stay" do
    list("A", "B", "C")
    %w[up top].each { |move| assert_selector "li#todo_0 button[type=button][aria-disabled=true][data-move=#{move}]" }
    assert_selector "li#todo_0 button[type=submit][value=down]"
    %w[down bottom].each { |move| assert_selector "li#todo_2 button[type=button][aria-disabled=true][data-move=#{move}]" }
    assert_selector "li#todo_2 button[type=submit][value=up]"
    assert_no_selector "button[disabled]"
  end

  it "is a list of one that cannot move at all" do
    list("A")
    assert_selector "button[aria-disabled=true]", count: 4
  end

  it "makes the buttons small squares with an icon and no visible text" do
    list("A", "B")
    assert_selector "li#todo_0 button.btn-xs.btn-square svg[aria-hidden=true]", count: 4
  end

  it "marks the row that was just moved" do
    list("A", "B", "C", highlight: 1)
    assert_selector "li#todo_1[data-controller=highlight]"
    assert_no_selector "li#todo_0[data-controller]"
  end

  it "is a sortable list, with a handle in each row that only a pointer uses" do
    list("A", "B")
    assert_selector "div[data-controller=sortable][data-sortable-handle-value='[data-sortable-handle]']"
    assert_selector "div[data-controller=sortable] ol[data-sortable-target=list]"
    assert_selector "li#todo_0[data-sortable-url='/planner/todos/0/position'][data-sortable-item-id='10'] [data-sortable-handle][aria-hidden=true]"
    assert_no_selector "[data-sortable-handle][tabindex]"
    assert_no_selector "[data-sortable-handle] button"
  end

  it "holds the form a drop is sent with: a PATCH with an empty after and before the drop fills" do
    list("A", "B")
    assert_selector "form[data-sortable-target=form] input[name=_method][value=patch]", visible: :all
    assert_selector "form[data-sortable-target=form] input[name=after][data-sortable-target=after]", visible: :all
    assert_selector "form[data-sortable-target=form] input[name=before][data-sortable-target=before]", visible: :all
  end

  it "says so when there is nothing in it" do
    list
    assert_text "Nothing to do."
    assert_no_selector "ol"
  end
end
