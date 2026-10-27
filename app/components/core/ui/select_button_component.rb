# Sets a record aside to link it (Core::Selection), or takes it back.
#
# title: the record's name, spoken after the label. A row's button says only
# "Select", and a screen reader adds which record.
#
# in_section: the request comes from a Links section, which is drawn again.
#
# icon: the name of an icon. The button is then a small square with only the
# icon, filled and highlighted when the record is selected, and it says what it
# does to a screen reader and in a tooltip.
class Core::UI::SelectButtonComponent < ApplicationComponent
  def initialize(entity_id:, selected:, label:, title: nil, in_section: false, size: nil, icon: nil)
    @entity_id = entity_id
    @selected = selected
    @label = label
    @title = title
    @in_section = in_section
    @size = size
    @icon = icon
  end

  def call
    form_with(url: helpers.selection_path, method: (@selected ? :delete : :post)) do
      safe_join([
        hidden_field_tag(:entity_id, @entity_id, id: nil),
        (hidden_field_tag(:in_section, "1", id: nil) if @in_section),
        button
      ].compact)
    end
  end

  private

  def button
    return render(Core::UI::ButtonComponent.new(type: :submit, variant: :secondary, size: @size)) { text } unless @icon

    name = [@label, @title].compact.join(" ")
    render(Core::UI::ButtonComponent.new(type: :submit, variant: (@selected ? :primary : :secondary), size: :xs, square: true, "aria-label": name, title: name)) do
      render(Core::UI::IconComponent.new(name: @icon, class: "size-4", **(@selected ? {fill: "currentColor"} : {})))
    end
  end

  def text = @title ? safe_join([@label, tag.span(" #{@title}", class: "sr-only")]) : @label
end
