class Planner::EventsController < Planner::ItemsController
  helper_method :repeat_form, :scope_choice

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

  # Changes an occurrence of a series.
  #
  # For this event only, it is the plain update. For the following events or
  # all of them, Planner::Recurrence::Edit makes the change. The rule belongs to
  # the series, so one event alone cannot change it.
  def update
    return super unless @item.occurrence?
    return super if scope_choice.scope == "this" && !rule_changed?

    if scope_choice.scope == "this"
      repeat_form.errors.add(:frequency, :needs_scope)
    elsif series_edit.call
      return dialog_done(kind_t("updated")) if in_dialog?

      return redirect_to back_path_or_default(@item), notice: kind_t("updated")
    end
    render :edit, status: :unprocessable_content
  end

  # Removes an occurrence of a series: this one, or more of them, as the scope
  # says (Planner::Recurrence::Delete).
  def destroy
    return super unless @item.occurrence?

    choice = Planner::Recurrence::ScopeChoice.of(params.dig(:apply, :scope),
      allowed: Planner::Recurrence::ScopeChoice::DELETE)
    if Planner::Recurrence::Delete.new(series: occurrence_series, item: @item, scope: choice.scope).call
      notice = (choice.scope == "this") ? kind_t("deleted") : t("planner.series.deleted.#{choice.scope}")
      return dialog_done(notice) if in_dialog?

      redirect_to back_path_or_default(@item), notice:, status: :see_other
    else
      render :edit, status: :unprocessable_content
    end
  end

  private

  def item_class = Planner::Event

  def permitted_attributes = super + [:day, :start_time, :end_time, :tracks_done]

  def repeating? = params[:linked_to].blank? && repeat_form.repeating?

  # What the repeat fields sent, as strings.
  #
  # Anything that is not a plain value is left out. An occurrence that sent no
  # repeat fields has its own.
  def repeat_form
    @repeat_form ||= if params[:repeat].present?
      permitted = params.slice(:repeat)
        .permit(repeat: [:frequency, :interval, :monthly, :ends, :until_on, :count, {weekdays: []}])
      Planner::Recurrence::Form.new(**(permitted[:repeat]&.to_h || {}).symbolize_keys)
    elsif @item&.occurrence?
      Planner::Recurrence::Form.from_rule(occurrence_series.rule)
    else
      Planner::Recurrence::Form.new
    end
  end

  def scope_choice = @scope_choice ||= Planner::Recurrence::ScopeChoice.of(params.dig(:apply, :scope))

  def rule_changed?
    params[:repeat].present? &&
      !repeat_form.same_rule_as?(Planner::Recurrence::Form.from_rule(occurrence_series.rule))
  end

  def series_edit
    Planner::Recurrence::Edit.new(series: occurrence_series, item: @item, scope: scope_choice.scope,
      attributes: item_params.to_h.symbolize_keys, form: repeat_form)
  end

  # The series the occurrence belongs to.
  #
  # An unsaved occurrence carries it. An event is looked up, which is a 404 for
  # a trashed or foreign one.
  def occurrence_series
    @occurrence_series ||= @item.new_record? ? @item.series : Planner::Series.owned_by(Current.user).kept.find(@item.series_id)
  end
end
