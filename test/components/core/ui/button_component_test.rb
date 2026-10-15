require "test_helper"

describe Core::UI::ButtonComponent do
  include ViewComponent::TestHelpers

  it "renders a button with the variant class and the block content" do
    render_inline(Core::UI::ButtonComponent.new(type: :submit, variant: :secondary)) { "Save" }
    assert_selector "button.btn.bg-base-100.border-base-300[type=submit]", text: "Save"
  end

  it "defaults to a primary button of type button" do
    render_inline(Core::UI::ButtonComponent.new) { "Go" }
    assert_selector "button.btn.btn-primary[type=button]", text: "Go"
  end

  it "rejects an unknown variant" do
    _ { render_inline(Core::UI::ButtonComponent.new(variant: :flashy)) { "x" } }.must_raise KeyError
  end

  it "has a danger variant for actions that destroy something" do
    render_inline(Core::UI::ButtonComponent.new(variant: :danger)) { "Delete" }
    assert_selector "button.btn.btn-error", text: "Delete"
  end

  it "is a link that looks like a button when it is given an address" do
    render_inline(Core::UI::ButtonComponent.new(href: "/planner/events/1/edit")) { "Edit event" }
    assert_selector "a.btn.btn-primary[href='/planner/events/1/edit']", text: "Edit event"
    assert_no_selector "button"
  end

  it "has a quiet gray secondary variant, apart from the page in both themes and visibly reacting to the pointer" do
    render_inline(Core::UI::ButtonComponent.new(variant: :secondary, href: "/x")) { "Show as list" }
    assert_selector "a.btn.bg-base-100.border-base-300.hover\\:bg-base-300", text: "Show as list"
  end

  it "shares the secondary look with the tabs and the period navigation, so there is one gray" do
    _(Core::UI::TabsComponent::BUTTON).must_include Core::UI::ButtonComponent::VARIANTS.fetch(:secondary)
  end

  it "can be a small square, for a button that holds only an icon" do
    render_inline(Core::UI::ButtonComponent.new(size: :xs, square: true)) { "x" }
    assert_selector "button.btn.btn-xs.btn-square"
  end
end
