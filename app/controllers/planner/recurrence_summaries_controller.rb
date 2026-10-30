# The Repeat fields of the event form, said in words (plain text).
#
# The form reads the rule back to its user as they change it. The words are
# Planner::Recurrence::Rule#summary: one place speaks them, here and in the
# lists.
class Planner::RecurrenceSummariesController < ApplicationController
  def show
    anchor = Date.iso8601(params[:day].to_s)
    rule = Planner::Recurrence::Form.new(**repeat_params).rule_for(anchor)
    render plain: rule&.summary.to_s
  rescue Date::Error
    render plain: ""
  end

  private

  def repeat_params
    params.fetch(:repeat, {})
      .permit(:frequency, :interval, :monthly, :ends, :until_on, :count, weekdays: [])
      .to_h.symbolize_keys
  end
end
