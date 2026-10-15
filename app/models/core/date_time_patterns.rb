# The strftime patterns of the date and time formats a user can choose: the header clock and the
# date and time helper (section 3) share them
module Core::DateTimePatterns
  DATE = {"dmy" => "%d/%m/%Y", "mdy" => "%m/%d/%Y", "ymd" => "%Y-%m-%d"}.freeze
  TIME = {"24h" => "%H:%M", "12h" => "%-I:%M %p"}.freeze
end
