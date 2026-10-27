# Sets a record aside to link it (Core::Selection), or takes it back.
#
# title: the record's name, spoken after the label. A row's button says only
# "Select", and a screen reader adds which record.
#
# in_section: the request comes from a Links section, which is drawn again.
class Core::UI::SelectButtonComponent < ApplicationComponent
  def initialize(entity_id:, selected:, label:, title: nil, in_section: false, size: nil)
    @entity_id = entity_id
    @selected = selected
    @label = label
    @title = title
    @in_section = in_section
    @size = size
  end

  def call
    form_with(url: helpers.selection_path, method: (@selected ? :delete : :post)) do
      safe_join([
        hidden_field_tag(:entity_id, @entity_id, id: nil),
        (hidden_field_tag(:in_section, "1", id: nil) if @in_section),
        render(Core::UI::ButtonComponent.new(type: :submit, variant: :secondary, size: @size)) { text }
      ].compact)
    end
  end

  private

  def text = @title ? safe_join([@label, tag.span(" #{@title}", class: "sr-only")]) : @label
end
