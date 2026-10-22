# Where a visit to an item began: the calendar, the agenda, the schedule or the
# todos, with its view and date.
#
# The item pages carry it in a `back` parameter and return to it.
# Only those pages (and a plain query string) are accepted, so the
# parameter can never send anyone to another page or site.
class Planner::BackLocation
  ALLOWED = %r{\A/planner/(?<page>calendar|agenda|schedule|todos)(?:\?[A-Za-z0-9_=&%.:-]*)?\z}

  attr_reader :path, :page

  def self.parse(value)
    match = ALLOWED.match(value) if value.is_a?(String)
    new(value, match[:page].to_sym) if match
  end

  def initialize(path, page)
    @path = path
    @page = page
    freeze
  end
end
