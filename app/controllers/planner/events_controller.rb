class Planner::EventsController < ApplicationController
  include Pagy::Method

  PAGE_SIZE = 25

  before_action :set_event, only: %i[show edit update destroy]

  def index
    @when = (params[:when] == "past") ? :past : :upcoming
    @pagy, @events = pagy(:offset, listing, limit: PAGE_SIZE)
  end

  def show
  end

  def new
    @event = Planner::Event.new(day: Date.current)
  end

  def create
    @event = Planner::Event.new(event_params.merge(user: Current.user))
    if @event.save
      redirect_to planner_events_path, notice: t(".created")
    else
      render :new, status: :unprocessable_content
    end
  end

  def edit
  end

  def update
    if @event.update(event_params)
      redirect_to planner_events_path, notice: t(".updated")
    else
      render :edit, status: :unprocessable_content
    end
  end

  # Permanent until the trash exists
  def destroy
    @event.destroy!
    redirect_to planner_events_path, notice: t(".deleted"), status: :see_other
  end

  private

  def events = Planner::Event.owned_by(Current.user)

  def set_event
    @event = events.find(params[:id])
  end

  # Never user_id, state, time_zone or done_at: those are not the form's to set
  def event_params
    params.expect(planner_event: [:title, :notes, :day, :start_time, :end_time, :tracks_done])
  end

  # Both orders walk index_planner_items_on_day, forwards or backwards
  def listing
    if @when == :past
      events.where(day: ...Date.current).order(day: :desc, starts_at: :desc)
    else
      events.where(day: Date.current..).order(:day, :starts_at)
    end
  end
end
