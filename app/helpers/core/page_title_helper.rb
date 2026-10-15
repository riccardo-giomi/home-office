module Core::PageTitleHelper
  # "Page | Home Office": the specific part first, the app name last
  def page_title
    [content_for(:title), t("core.app_name")].compact_blank.join(" | ")
  end
end
