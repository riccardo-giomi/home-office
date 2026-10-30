# Changes a repeating event for more than itself.
#
# "This and following" splits the series at the occurrence: the old part ends
# the day before, and a new part of the same chain takes over. "All" changes the
# whole chain. The change of the occurrence alone ("this event") is a plain
# update of the event, and it is not made here.
#
# The rules, which the user sees in the results:
#
# - Touched rows (the events a series made) get only what was changed in the
#   form, so a row edited on its own keeps its other fields. The edited event
#   gets everything posted.
# - The day belongs to the rule. "Following" can move it: the new part is
#   anchored on the new day, so the day-based part of the rule follows it.
#   "All" ignores it.
# - A row that the changed rule no longer gives becomes an event of its own.
#   Nothing is deleted.
# - A rule change on "all" puts the chain back into one series.
class Planner::Recurrence::Edit
  SCOPES = %w[this following all].freeze
  FIELDS = %i[title notes priority tracks_done].freeze

  # series: the part the occurrence belongs to.
  # item: the occurrence (unsaved or an event), not yet changed.
  # attributes: what the form posted for the event.
  # form: the repeat fields it posted.
  def initialize(series:, item:, scope:, attributes:, form:)
    raise ArgumentError, "unknown scope: #{scope}" unless %w[following all].include?(scope)

    @series = series
    @item = item
    @scope = scope
    @attributes = attributes
    @form = form
  end

  # True when it changed everything it should.
  #
  # Otherwise nothing changed, and the reasons are in the errors of the item and
  # of the form.
  def call
    original = snapshot
    @item.assign_attributes((@scope == "all") ? @attributes.except(:day) : @attributes)
    return false unless @item.valid?

    @changed = snapshot.reject { |name, value| name == :day || original[name] == value }.keys
    @day_moved = @scope == "following" && @item.day != original[:day]
    return true if @changed.empty? && !@day_moved && @form.same_rule_as?(Planner::Recurrence::Form.from_rule(@series.rule))

    done = false
    Planner::Series.transaction do
      done = (@scope == "following") ? following : all
      raise ActiveRecord::Rollback unless done
    end
    done
  rescue ActiveRecord::StaleObjectError
    refuse(:base, :stale_series)
  rescue ActiveRecord::RecordNotUnique
    refuse(:day, :taken)
  rescue ActiveRecord::RecordInvalid => error
    error.record.errors.full_messages.each { |message| @item.errors.add(:base, message) }
    false
  end

  private

  def snapshot
    {title: @item.title, notes: @item.notes.to_s, priority: @item.priority, tracks_done: @item.tracks_done, day: @item.day, start_time: @item.start_time.to_s, end_time: @item.end_time.to_s}
  end

  def refuse(attribute, type, **options)
    @item.errors.add(attribute, type, **options)
    false
  end

  def times_changed? = @changed.include?(:start_time) || @changed.include?(:end_time)

  # What a series takes from the change.
  def series_changes
    @series_changes ||= FIELDS.select { |name| @changed.include?(name) }.to_h { |name| [name, (name == :notes) ? @item.notes.presence : @item.public_send(name)] }.tap do |changes|
      next unless times_changed?

      timed = @item.starts_at && @item.ends_at
      changes.merge!(start_time: (@item.start_time if timed), duration_minutes: (((@item.ends_at - @item.starts_at) / 60).to_i if timed))
    end
  end

  # What a touched row takes from the change.
  def row_changes
    @row_changes ||= FIELDS.select { |name| @changed.include?(name) }.to_h { |name| [name, @item.public_send(name)] }.tap do |changes|
      changes.merge!(start_time: @item.start_time.to_s, end_time: @item.end_time.to_s) if times_changed?
    end
  end

  def following
    day = @item.occurrence_on
    anchor = @day_moved ? @item.day : day
    previous = @series.dates([@series.from_on, @series.starts_on].compact.max..(day - 1), skip: []).last
    if previous && anchor <= previous
      return refuse(:day, :not_after_previous, date: I18n.l(previous, format: "%-d %b %Y"))
    end

    rule = new_rule(anchor, day, previous)
    return false unless rule

    changes_for_later = later_parts(day)
    old_ends_on = @series.ends_on
    if previous
      @series.update!(ends_on: [day, anchor].min - 1)
      target = Planner::Series.create!(@series.slice(:user_id, :title, :notes, :priority, :tracks_done, :start_time, :duration_minutes, :time_zone)
        .merge(series_changes).merge(starts_on: anchor, ends_on: old_ends_on, rrule: rule.to_rrule, chain_id: @series.chain_key))
      Planner::Event.where(series_id: @series.id, occurrence_on: day..).update_all(series_id: target.id)
      Planner::SeriesExclusion.where(series_id: @series.id, excluded_on: day..).update_all(series_id: target.id)
    elsif @series.from_on && anchor == day
      # The earlier days are hidden, not gone: the anchor, and with it a count,
      # stays where it was.
      @series.update!(series_changes.merge(rrule: rule.to_rrule))
      target = @series
    else
      @series.update!(series_changes.merge(starts_on: anchor, from_on: nil, rrule: rule.to_rrule))
      target = @series
    end
    save_item(target, anchor)
    reconcile(target)
    changes_for_later.each { |part| change_in_place(part) }
    true
  end

  def all
    parts = @series.chain.reject(&:trashed?)
    return collapse(parts) unless @form.same_rule_as?(Planner::Recurrence::Form.from_rule(@series.rule))

    parts.each { |part| change_in_place(part) }
    true
  end

  # The rule from the new day on.
  #
  # The series' own when nothing about it was touched, else what the fields say.
  def new_rule(anchor, day, previous)
    old = @series.rule
    rule = (@form.same_rule_as?(Planner::Recurrence::Form.from_rule(old)) && anchor == day) ? old : rule_from_form(anchor)
    return unless rule

    # A count is shared out: the new part has what the earlier one did not use.
    if previous && rule.count && rule.count == old.count
      used = Planner::Recurrence::Expander.dates(rrule: @series.rrule, starts_on: @series.starts_on, start_time: @series.start_time, time_zone: @series.time_zone, between: @series.starts_on..(day - 1)).size
      rule = rule.with(count: old.count - used)
    end
    rule
  end

  # The parts of the chain that begin after the occurrence.
  #
  # They take the changes of the template, not a new rule.
  def later_parts(day) = @series.chain.reject { |part| part.trashed? || part.id == @series.id || part.starts_on <= day }

  def change_in_place(part)
    part.update!(series_changes) if series_changes.any?
    apply_to_rows(Planner::Event.where(series_id: part.id))
  end

  def apply_to_rows(rows)
    return if row_changes.empty?

    rows.each { |row| row.update!(row_changes) }
  end

  # Saves the edited event with everything posted, on the new part, and on the
  # new day if it moved.
  def save_item(target, anchor)
    unless @item.persisted?
      # An unsaved occurrence that the new rule does not give on its day would
      # vanish. It stays, as an event of its own.
      keep_alone unless target.dates(anchor..anchor, skip: []).any?
      return
    end

    @item.series_id = target.id
    @item.occurrence_on = anchor if @day_moved
    @item.save!
  end

  def keep_alone
    @item.series = nil
    @item.occurrence_on = nil
    @item.save!
  end

  # The rule of the fields.
  #
  # None given is said in words: a request that skips the select can ask for
  # "does not repeat".
  def rule_from_form(anchor)
    rule = @form.rule_for(anchor)
    @form.errors.add(:frequency, :invalid) if rule.nil? && @form.errors.empty?
    rule
  end

  # Touched rows that the rule no longer gives leave the series. The others take
  # the changes.
  def reconcile(target)
    # Events in the trash stay as they are: a delete of the past trashed them on
    # purpose.
    rows = Planner::Event.where(series_id: target.id).kept.to_a
    return if rows.empty?

    produced = target.dates(rows.map(&:occurrence_on).min..rows.map(&:occurrence_on).max, skip: []).to_set
    kept, gone = rows.partition { |row| produced.include?(row.occurrence_on) }
    Planner::Event.where(id: gone.map(&:id)).update_all(series_id: nil, occurrence_on: nil) if gone.any?
    apply_to_rows(kept.reject { |row| row.id == @item.id })
  end

  # A new rule for the whole chain.
  #
  # The first part keeps its anchor and takes everything over.
  def collapse(parts)
    rule = rule_from_form(@item.occurrence_on)
    return false unless rule

    root = parts.find { |part| part.chain_id.nil? } || parts.first
    last = parts.max_by(&:starts_on)
    (parts - [root]).each do |part|
      Planner::Event.where(series_id: part.id).update_all(series_id: root.id)
      Planner::SeriesExclusion.where(series_id: part.id).where.not(excluded_on: root.exclusions.select(:excluded_on)).update_all(series_id: root.id)
      part.destroy!
    end
    # A count shared out between the parts is the count of the whole again,
    # unless the user typed another.
    rule = rule.with(count: root.rule.count) if rule.count && root.rule.count && @form.count == @series.rule.count
    root.update!(series_changes.merge(rrule: rule.to_rrule, ends_on: last.ends_on))
    save_item(root, @item.occurrence_on)
    reconcile(root)
    true
  end
end
