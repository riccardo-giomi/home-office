class Core::UI::FieldComponent < ApplicationComponent
  CLASSES = {select: "select w-full", check_box: "checkbox", text_area: "textarea w-full"}.freeze

  def initialize(form:, attribute:, label:, as: :text_field, hint: nil, choices: nil, **input_options)
    @form = form
    @attribute = attribute
    @label = label
    @as = as
    @hint = hint
    @choices = choices
    @input_options = input_options
  end

  def field_id = @form.field_id(@attribute)

  # Markup between the label and the control. Nothing by default.
  def readout = nil

  # Attributes of the element that wraps the field. None by default.
  def root_attributes = {}

  def errors
    object = @form.object
    object.respond_to?(:errors) ? object.errors.messages_for(@attribute) : []
  end

  def control
    if @as == :select
      @form.select(@attribute, @choices, {}, input_attributes)
    else
      @form.public_send(@as, @attribute, input_attributes)
    end
  end

  private

  # The ids of the elements that describe the input, in the order a screen
  # reader reads them.
  def described_by = [@hint && "#{field_id}_hint", errors.any? && "#{field_id}_error"].select(&:itself)

  def input_attributes
    {
      class: CLASSES.fetch(@as, "input w-full"),
      "aria-describedby": described_by.join(" ").presence,
      "aria-invalid": ("true" if errors.any?)
    }.merge(@input_options).compact
  end
end
