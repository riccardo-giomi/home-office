class Planner::EventsController < Planner::ItemsController
  helper_method :repeat_form

  # An event that repeats makes a series, not an event.
  #
  # Its first occurrence is unsaved, like the others. An event made to be linked
  # is always a single event, whatever the repeat fields say.
  def create
    return super unless repeating?

    @item = item_class.new(item_params.merge(user: Current.user))
    @item.validate
    rule = repeat_form.rule_for(@item.day) if @item.day
    if @item.errors.empty? && rule
      series = Planner::Series.from_event(@item, rule)
      if series.save
        return dialog_done(kind_t("created")) if in_dialog?

        return redirect_to back_path_or_default(@item), notice: kind_t("created")
      end
      series.errors.full_messages.each { |message| @item.errors.add(:base, message) }
    end
    render :new, status: :unprocessable_content
  end

  private

  def item_class = Planner::Event

  def permitted_attributes = super + [:day, :start_time, :end_time, :tracks_done]

  def repeating? = params[:linked_to].blank? && repeat_form.repeating?

  # What the repeat fields sent, as strings.
  #
  # Anything that is not a plain value is left out.
  def repeat_form
    @repeat_form ||= if params[:repeat].present?
      permitted = params.slice(:repeat)
        .permit(repeat: [:frequency, :interval, :monthly, :ends, :until_on, :count, {weekdays: []}])
      Planner::Recurrence::Form.new(**(permitted[:repeat]&.to_h || {}).symbolize_keys)
    else
      Planner::Recurrence::Form.new
    end
  end
end
