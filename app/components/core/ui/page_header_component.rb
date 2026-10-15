# The top of a page about one thing: its heading, and the way back right under it. The back link is a
# link, kept well away from the buttons at the bottom of the page. A page that opens in a dialog gives its
# heading id="dialog-title", which names the dialog.
class Core::UI::PageHeaderComponent < ApplicationComponent
  def initialize(title:, back_href: nil, back_label: nil, id: nil)
    @title = title
    @id = id
    @back_href = back_href
    @back_label = back_label
  end

  def call
    return tag.h1(@title, id: @id, class: "mb-4 text-2xl font-bold wrap-anywhere") unless @back_href

    safe_join([
      tag.h1(@title, id: @id, class: "mb-2 text-2xl font-bold wrap-anywhere"),
      tag.p(class: "mb-6") { back_link }
    ])
  end

  private

  def back_link = (render(Core::UI::LinkComponent.new(href: @back_href)) { @back_label } if @back_href)
end
