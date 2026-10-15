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

  def input_attributes
    describedby = [@hint && "#{field_id}_hint", errors.any? && "#{field_id}_error"].select(&:itself).join(" ").presence
    {
      class: CLASSES.fetch(@as, "input w-full"),
      "aria-describedby": describedby,
      "aria-invalid": ("true" if errors.any?)
    }.merge(@input_options).compact
  end
end
