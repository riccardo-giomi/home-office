# Stands in for the Links section of a record that does not exist yet.
#
# That is an occurrence of a repeating event nobody has touched. It has the same
# heading, a sentence that says why, and what the page puts inside it (the
# button that makes the record).
class Core::UI::LinksPlaceholderComponent < ApplicationComponent
  def initialize(text:, id: "links-placeholder")
    @text = text
    @id = id
  end

  def call
    tag.div(id: @id, role: "group", "aria-labelledby": "#{@id}-heading", class: "mt-8") do
      safe_join([
        tag.h2(t("core.ui.links_section.placeholder_heading"), id: "#{@id}-heading", class: "mb-2 text-lg font-semibold"),
        tag.p(@text, class: "mb-2"),
        content
      ])
    end
  end
end
