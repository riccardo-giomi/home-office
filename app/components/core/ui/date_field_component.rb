# A date field that also shows its date in the format the user chose in the
# preferences.
#
# The browser draws a date input in its own format (set by its language), which
# can read the same digits in another order: 01/12/2026 is the 1st of December
# for one user and the 12th of January for another. A line between the label and
# the input says the date the field holds, with its weekday, in the user's
# format. The page draws the line when it renders the field, and the
# `date-readout` controller keeps it in step with the input.
#
# The line describes the input (`aria-describedby`), so a screen reader reads
# it when the field gets the focus. It is not a live region: a date input changes
# once for each part the user types, and announcing each one would be noise.
class Core::UI::DateFieldComponent < Core::UI::FieldComponent
  def initialize(form:, attribute:, label:, hint: nil, **input_options)
    data = {date_readout_target: "input", action: "input->date-readout#update change->date-readout#update"}
    super(form:, attribute:, label:, as: :date_field, hint:, **input_options.merge(data: data.merge(input_options.fetch(:data, {}))))
  end

  def root_attributes
    {data: {controller: "date-readout", date_readout_pattern_value: helpers.date_pattern, date_readout_day_names_value: I18n.t("date.day_names")}}
  end

  def readout
    tag.p(text, id: readout_id, class: "mb-1 min-h-5 text-sm text-base-content/80", data: {date_readout_target: "text"})
  end

  private

  def readout_id = "#{field_id}_readout"

  def described_by = [readout_id, *super]

  # The weekday and the date, or nothing for an empty or unreadable value.
  def text
    date = Date.iso8601(@form.object.public_send(@attribute).to_s)
    "#{I18n.t("date.day_names")[date.wday]} #{date.strftime(helpers.date_pattern)}"
  rescue Date::Error
    ""
  end
end
