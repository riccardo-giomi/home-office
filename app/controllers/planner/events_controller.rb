class Planner::EventsController < ApplicationController
  include Planner::EventPages

  before_action :set_event, only: %i[show edit update destroy]

  def show
  end

  def new
    @event = Planner::Event.new(day: Date.current)
  end

  def create
    @event = Planner::Event.new(event_params.merge(user: Current.user))
    if @event.save
      return dialog_done(t(".created")) if in_dialog?

      redirect_to back_path_or_day(@event), notice: t(".created")
    else
      render :new, status: :unprocessable_content
    end
  end

  def edit
  end

  def update
    if @event.update(event_params)
      return dialog_done(t(".updated")) if in_dialog?

      redirect_to planner_event_path(@event, back: back_param), notice: t(".updated")
    else
      render :edit, status: :unprocessable_content
    end
  end

  # Permanent until the trash exists.
  def destroy
    @event.destroy!
    return dialog_done(t(".deleted")) if in_dialog?

    redirect_to back_path_or_day(@event), notice: t(".deleted"), status: :see_other
  end

  private

  def events = Planner::Event.owned_by(Current.user)

  def set_event
    @event = events.find(params[:id])
  end

  # Never user_id, state, time_zone or done_at: those are not for the form to
  # set.
  def event_params
    params.expect(planner_event: [:title, :notes, :day, :start_time, :end_time, :tracks_done])
  end

  def back_path_or_day(event) = back_location&.path || planner_calendar_path(date: event.day&.iso8601)
end
