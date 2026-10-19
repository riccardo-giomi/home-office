class Core::UI::FrameDialogComponentPreview < ViewComponent::Preview
  # One per page, hidden until a link fills it: the Theme page leaves it out.
  #
  # Drawn open here, with a page in it, so it can be judged; in the app it is a
  # modal <dialog> opened by the script once its frame has loaded.
  def self.page_level? = true

  def showing_an_event
    dialog = Core::UI::FrameDialogComponent.new(id: "event-dialog-demo", frame_id: "event-dialog-demo-frame", open: true)
    page = Core::UI::PageHeaderComponent.new(title: "Planning", back_href: nil)
    html = ApplicationController.render(page, layout: false) + ApplicationController.helpers.tag.p("10:00–11:30, with the notes below.", class: "mb-4")
    render(dialog.with_content(html.html_safe))
  end
end
