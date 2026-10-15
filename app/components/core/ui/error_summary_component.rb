class Core::UI::ErrorSummaryComponent < ApplicationComponent
  def initialize(record:, id: "error-summary", autofocus: true)
    @record = record
    @id = id
    @autofocus = autofocus
  end

  def render? = @record.errors.any?

  # [message, field id or nil]; the id matches form_with's default for a model
  def items
    @record.errors.map do |error|
      [error.full_message, (error.attribute == :base) ? nil : "#{@record.model_name.param_key}_#{error.attribute}"]
    end
  end
end
