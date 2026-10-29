# A titled box that belongs to the page around it, such as the link picker: a
# section named by its own heading.
class Core::UI::PanelComponent < ApplicationComponent
  # data: the section's data attributes, such as a Stimulus controller.
  def initialize(title:, id:, data: {})
    @title = title
    @id = id
    @data = data
  end

  def call
    tag.section("aria-labelledby": "#{@id}-title", id: @id, data: @data, class: "mt-4 rounded border border-base-300 bg-base-100 p-3") do
      safe_join([tag.h3(@title, id: "#{@id}-title", class: "mb-2 font-semibold"), content])
    end
  end
end
