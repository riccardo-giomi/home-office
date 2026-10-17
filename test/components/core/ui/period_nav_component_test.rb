require "test_helper"

describe Core::UI::PeriodNavComponent do
  include ViewComponent::TestHelpers

  def nav
    views = [["Month", "/month", true], ["Week", "/week", false], ["Agenda", "/agenda", false]]
    Core::UI::PeriodNavComponent.new(label: "Calendar navigation", previous_link: ["Previous month", "/prev"],
      next_link: ["Next month", "/next"], today_href: "/today", views:)
  end

  it "is a labeled nav with previous, today and next links" do
    render_inline(nav)
    assert_selector "nav[aria-label='Calendar navigation']"
    assert_selector "a[href='/prev']", text: "Previous month"
    assert_selector "a[href='/next']", text: "Next month"
    assert_selector "a[href='/today']", text: I18n.t("core.ui.period_nav.today")
  end

  it "does not repeat the period: the sticky header already names it" do
    render_inline(nav)
    assert_no_selector "p"
    assert_no_text "October 2026"
  end

  it "marks exactly the current view, with a check as well as the attribute" do
    render_inline(nav)
    assert_selector "a[aria-current=true]", count: 1
    assert_selector "a[aria-current=true][href='/month'] svg"
    assert_no_selector "a[href='/week'] svg"
  end

  it "keeps every link at least 24 px tall" do
    render_inline(nav)
    assert_selector "a.btn", count: 6
  end

  it "makes the current view the one solid button, with a check, and every other button a plain one" do
    render_inline(nav)
    assert_selector "a.btn-neutral[aria-current=true][href='/month'] svg", count: 1
    assert_selector "a.btn-neutral", count: 1
    assert_selector "a.hover\\:bg-base-300", count: 5
  end

  it "lists the views as a list of separate buttons, not a joined group" do
    render_inline(nav)
    assert_selector "ul li a", count: 3
    assert_no_selector ".join"
  end

  describe "layout" do
    it "puts the views on the first line, and the steps on the second, pushed to the start" do
      render_inline(nav)
      html = page.native.to_html
      assert_operator html.index("Month"), :<, html.index("Previous month")
      assert_selector "nav > div:first-child ul", count: 1
      assert_selector "nav > div:last-child a[href='/prev']"
    end
  end
end
