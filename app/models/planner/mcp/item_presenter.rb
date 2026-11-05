# An item as an agent reads it.
#
# Short keys, nothing that is null or the default, and clock times in the time
# zone of the user (the zone of the item is named only when it differs).
#
# An unsaved occurrence is named by its series and date (`s7@2026-11-03`). A
# saved one is named by its id and, as `occurrence`, by the same series and
# date, which keeps working.
class Planner::Mcp::ItemPresenter
  NOTES_IN_LISTS = 200

  # Returns how many links each of these items has to records that are not in
  # the trash, by id. It takes one query, whatever the number of items.
  def self.link_counts(ids)
    ids = ids.to_set
    return {} if ids.empty?

    pairs = Core::Link.involving(ids.to_a).pluck(:first_entity_id, :second_entity_id)
    others = pairs.flat_map { |first, second| [first, second] }.reject { |id| ids.include?(id) }
    kept = Core::Entity.kept.where(id: others).pluck(:id).to_set
    pairs.each_with_object(Hash.new(0)) do |(first, second), counts|
      counts[first] += 1 if ids.include?(first) && (kept.include?(second) || ids.include?(second))
      counts[second] += 1 if ids.include?(second) && (kept.include?(first) || ids.include?(first))
    end
  end

  # A series in the trash: one entry for all that went with it.
  def self.trashed_series(group)
    series = group.first
    {id: "s#{group.id}", type: "event", title: series.title, repeat: series.rule&.summary, trashed: true}
  end

  # links: a count (in lists) or nil. series: the series of the item (only for
  # the whole item). trashed: true in the lists of the trash.
  def initialize(item, full: false, links: nil, series: nil, trashed: false)
    @item = item
    @full = full
    @links = links
    @series = series
    @trashed = trashed
  end

  def to_h
    {
      id:, type: @item.class.kind, title: @item.title, day:,
      start: (@item.start_time if timed?), end: (@item.end_time if timed?), time_zone:,
      priority: (@item.priority unless @item.normal?), state: (@item.state unless @item.active?),
      done: (true if @item.done?), tracks_done: (true if event? && @item.tracks_done?),
      notes:, notes_truncated: (true if truncated?), occurrence: (name if saved_occurrence?),
      series: series_h, links: (@links if @links.to_i.positive?), trashed: (true if @trashed)
    }.compact
  end

  private

  def id = (@item.new_record? && @item.occurrence?) ? name : @item.id.to_s

  def name = "s#{@item.series_id}@#{@item.occurrence_on.iso8601}"

  def saved_occurrence? = @item.persisted? && @item.occurrence?

  def timed? = @item.timed? && @item.starts_at.present?

  def event? = @item.is_a?(Planner::Event)

  def day = (@item.day.iso8601 if @item.timed? && @item.day)

  def time_zone = (@item.time_zone if timed? && @item.time_zone != Time.zone.name)

  def notes
    text = @item.notes.presence
    (@full || text.nil?) ? text : text.first(NOTES_IN_LISTS)
  end

  def truncated? = !@full && @item.notes.to_s.size > NOTES_IN_LISTS

  def series_h
    return unless @full && @series

    {id: "s#{@series.id}", repeat: @series.rule&.summary}
  end
end
