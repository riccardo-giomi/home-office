# A titled box that belongs to the page around it, such as the link picker: a
# section named by its own heading.
class Core::UI::PanelComponent < ApplicationComponent
  def initialize(title:, id:)
    @title = title
    @id = id
  end

  def call
    tag.section("aria-labelledby": "#{@id}-title", id: @id, class: "mt-4 rounded border border-base-300 bg-base-100 p-3") do
      safe_join([tag.h3(@title, id: "#{@id}-title", class: "mb-2 font-semibold"), content])
    end
  end
end
