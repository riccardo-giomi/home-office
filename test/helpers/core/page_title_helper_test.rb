require "test_helper"

class Core::PageTitleHelperTest < ActionView::TestCase
  tests Core::PageTitleHelper

  it "puts the page name first and the app name last" do
    content_for(:title, "Calendar")
    assert_equal "Calendar | Home Office", page_title
  end

  it "is just the app name when the page sets no title" do
    assert_equal "Home Office", page_title
  end
end
