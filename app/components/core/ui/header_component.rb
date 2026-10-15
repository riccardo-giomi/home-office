class Core::UI::HeaderComponent < ApplicationComponent
  def initialize(page_title:, menu: true)
    @page_title = page_title
    @menu = menu
  end
end
