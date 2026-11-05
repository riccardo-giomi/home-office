# Which items a list asks for.
#
# The types, a range of days (or one of the three views of the controllers), a
# state, done or not, a part of the title, or the trash.
#
# The rules of the controllers and models are used, not copied: the unsaved occurrences of series
# come from Planner::Occurrences, the views from ImportantEvents, `Event.missed`
# and `Task.forgotten`, and the trash from Planner::Trash.
#
# Input that is not valid raises Invalid, whose message names what would have
# been valid.
class Planner::Mcp::ItemQuery
  class Invalid < StandardError; end

  TYPES = %w[event task todo].freeze
  STATES = %w[active abandoned cancelled any].freeze
  VIEWS = %w[important missed forgotten].freeze
  DEFAULT_DAYS = 14
  MAX_DAYS = 366
  MAX_LIMIT = 200
  DATE = /\A\d{4}-\d{2}-\d{2}\z/

  Page = Data.define(:entries, :total, :trashed)

  def initialize(user, today:, type: nil, from: nil, to: nil, view: nil, state: nil, done: nil, q: nil,
    trashed: false, limit: 50, offset: 0)
    @user = user
    @today = today
    @type = type
    @view = view
    @state = state || "active"
    @done = done
    @q = q
    @trashed = trashed
    @limit = limit
    @offset = offset
    @from = day(from, "from")
    @to = day(to, "to")
    refuse_filters_a_view_ignores(type:, from:, to:, state:, done:) if view
  end

  def page
    return trashed_page if @trashed

    all = entries
    Page.new(entries: all.drop(@offset).first(@limit), total: all.size, trashed: false)
  end

  private

  def entries
    return view_entries if @view

    types = @type ? [@type] : TYPES
    dated = []
    dated += events if types.include?("event")
    dated += tasks if types.include?("task")
    dated = Planner::Occurrences.chronological(dated)
    dated + (types.include?("todo") ? todos : [])
  end

  def range
    from = @from || @today
    to = @to || from + (DEFAULT_DAYS - 1)
    raise Invalid, "to is before from." if to < from
    raise Invalid, "The range is at most #{MAX_DAYS} days." if (to - from) >= MAX_DAYS

    from..to
  end

  def events = Planner::Occurrences.for(@user, range, title: @q).select { |item| wanted?(item) }

  def tasks = Core::TitleMatch.apply(Planner::Task.owned_by(@user).kept.on_days(range), @q).select { |item| wanted?(item) }

  def todos = Core::TitleMatch.apply(Planner::Todo.owned_by(@user).kept.in_order, @q).select { |item| wanted?(item) }

  def wanted?(item)
    (@state == "any" || item.state == @state) && (@done.nil? || item.done? == @done)
  end

  # The views have their own rules (state, day, kind). Only the title filter
  # and the paging apply.
  def view_entries
    list = case @view
    when "important" then Planner::ImportantEvents.new(@user, today: @today).entries
    when "missed" then Planner::Event.owned_by(@user).missed(@today).order(:day, :starts_at, :id).to_a
    when "forgotten" then Planner::Task.owned_by(@user).forgotten(@today).order(:day, :starts_at, :id).to_a
    end
    @q.present? ? list.select { |item| item.title.downcase.include?(@q.strip.downcase) } : list
  end

  # Series first (one entry each, as on the trash page), then the items, newest
  # first. The paging runs over both.
  def trashed_page
    trash = Planner::Trash.new(@user, type: @type)
    groups = trash.series_groups.select { |group| @q.blank? || group.first.title.downcase.include?(@q.strip.downcase) }
    scope = Core::TitleMatch.apply(trash.items, @q)
    first_groups = groups.drop(@offset).first(@limit)
    skip = [@offset - groups.size, 0].max
    items = (@limit > first_groups.size) ? scope.offset(skip).limit(@limit - first_groups.size).to_a : []
    Page.new(entries: first_groups + items, total: groups.size + scope.count, trashed: true)
  end

  # A filter that a view would ignore is an error, so an answer is never less
  # filtered than the agent asked.
  def refuse_filters_a_view_ignores(filters)
    given = filters.compact.keys
    return if given.empty?

    raise Invalid, "view cannot be combined with #{given.join(", ")}; only q, limit and offset go with a view."
  end

  def day(value, name)
    return if value.nil?
    raise Invalid, "#{name} must be an ISO 8601 date such as 2026-10-11." unless DATE.match?(value.to_s)

    Date.strptime(value.to_s, "%Y-%m-%d")
  rescue Date::Error
    raise Invalid, "#{name} must be an ISO 8601 date such as 2026-10-11."
  end
end
