# One choice of a group, with its label beside it.
#
# It is a radio button (one value among several) or a check box of a list
# (`weekdays[]`). The group itself is a FieldsetComponent, whose legend names
# it. The label is the click target, 24 px high at least.
class Core::UI::ChoiceComponent < ApplicationComponent
  TYPES = %i[radio_button check_box].freeze

  def initialize(form:, attribute:, value:, label:, type:, hint: nil, **input_options)
    raise ArgumentError, "unknown type: #{type}" unless TYPES.include?(type)

    @form = form
    @attribute = attribute
    @value = value
    @label = label
    @type = type
    @hint = hint
    @input_options = input_options
  end

  def call
    tag.div(class: "mb-1") do
      safe_join([tag.label(safe_join([control, tag.span(@label)]), class: "inline-flex min-h-6 items-center gap-2"), hint].compact)
    end
  end

  private

  def control_id = @form.field_id(@attribute, @value.to_s.downcase)

  def hint_id = "#{control_id}_hint"

  def hint = (tag.p(@hint, id: hint_id, class: "ml-7 text-sm text-base-content/80") if @hint)

  def control
    options = {class: ((@type == :radio_button) ? "radio" : "checkbox"), "aria-describedby": (hint_id if @hint)}.merge(@input_options).compact
    if @type == :radio_button
      @form.radio_button(@attribute, @value, options)
    else
      checked = Array(@form.object.public_send(@attribute)).include?(@value)
      @form.check_box(@attribute, options.merge(multiple: true, checked:), @value, nil)
    end
  end
end
