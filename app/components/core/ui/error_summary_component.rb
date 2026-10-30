class Core::UI::ErrorSummaryComponent < ApplicationComponent
  # also: other records whose fields sit in the same form, like the repeat
  # fields of the event form. Their errors are listed after the record's own,
  # each linked to its own field.
  def initialize(record:, id: "error-summary", autofocus: true, also: [])
    @records = [record, *also]
    @id = id
    @autofocus = autofocus
  end

  def render? = @records.any? { |record| record.errors.any? }

  # [message, field id or nil]; the id matches form_with's default for a model
  def items
    @records.flat_map do |record|
      record.errors.map do |error|
        [error.full_message, (error.attribute == :base) ? nil : "#{record.model_name.param_key}_#{error.attribute}"]
      end
    end
  end
end
