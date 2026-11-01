# Demo data, development-only.
# Running `bin/rails db:seed` again gives the same data with fresh dates.
# Add records below this guard, test/seeds_test.rb is watching you...
return unless Rails.env.development?

{"demo-admin@example.com" => :admin, "demo-user@example.com" => :user}.each do |email, role|
  User.find_or_create_by!(email_address: email) { |user| user.assign_attributes(role:, password: "development-only-password") }
end

demo_user = User.find_by!(email_address: "demo-user@example.com")
# The demo records are made again on every run, so their dates stay around
# today.
#
# Important: anything else the demo user made goes too.
Planner::Item.owned_by(demo_user).destroy_all

# Series are not items. Their events are already gone, so this only removes the
# series.
Planner::Series.purge(Planner::Series.owned_by(demo_user))

# A few events around today for the list to show. Two are for the lists of late
# and important events: an invoice that was not sent, and an urgent deadline.
[
  {title: "Dentist", days: 2, times: %w[09:30 10:15]},
  {title: "Team lunch", days: 5, times: %w[12:30 14:00]},
  {title: "Planning", days: 0, times: %w[10:00 11:30], tracks_done: true},
  {title: "Code review", days: 0, times: %w[10:30 11:00], tracks_done: true, state: "abandoned"},
  {title: "Call with the client", days: 0, times: %w[11:00 12:00], tracks_done: true},
  {title: "Gym", days: 0, times: %w[18:00 19:00], tracks_done: true},
  {title: "Pay the rent", days: 9, tracks_done: 1},
  {title: "Rent paid last month", days: -20, tracks_done: 1, done: true},
  {title: "Send the invoice", days: -4, tracks_done: 1},
  {title: "Client deadline", days: 3, priority: :urgent}
].each do |attrs|
  Planner::Event.create!(user: demo_user, title: attrs[:title]) do |event|
    event.assign_attributes(day: Date.current + attrs[:days], tracks_done: attrs.fetch(:tracks_done, 0),
      state: attrs.fetch(:state, "active"), priority: attrs.fetch(:priority, :normal))
    event.start_time, event.end_time = attrs[:times] if attrs[:times]
    event.mark_done(true) if attrs[:done]
  end
end

# Tasks around today: timed, all-day, done, abandoned (one of them short and
# overlapping, the worst case for a card) and older ones.
[
  {title: "Write the report", days: 0, times: %w[09:00 10:30]},
  {title: "Water the plants", days: 0, times: %w[09:30 09:45], state: "abandoned"},
  {title: "Buy stamps", days: 0},
  {title: "Call the bank", days: 0, done: true},
  {title: "Book the train", days: 1, times: %w[14:00 14:30]},
  {title: "Sort the attic", days: -3, state: "abandoned"},
  {title: "Renew the passport", days: -5},
  {title: "Return the library book", days: -12}
].each do |attrs|
  Planner::Task.create!(user: demo_user, title: attrs[:title]) do |task|
    task.assign_attributes(day: Date.current + attrs[:days], state: attrs.fetch(:state, "active"))
    task.start_time, task.end_time = attrs[:times] if attrs[:times]
    task.mark_done(true) if attrs[:done]
  end
end

# Todos: the urgent and high ones are put on top of the list as they are
# created, the rest at the bottom.
[
  {title: "Water the plants"},
  {title: "Call mom", priority: :high},
  {title: "Finish the book", done: true},
  {title: "Renew the license", priority: :low},
  {title: "Fix the leaking tap", priority: :urgent},
  {title: "Sort the photos", notes: "From the summer trip."}
].each do |attrs|
  Planner::Todo.create!(user: demo_user, title: attrs[:title]) do |todo|
    todo.assign_attributes(attrs.slice(:priority, :notes))
    todo.mark_done(true) if attrs[:done]
  end
end

# A few priorities on the events and tasks too, so the lists show the markers.
{Planner::Event => {"Dentist" => :high, "Planning" => :urgent, "Code review" => :urgent}, Planner::Task => {"Write the report" => :high, "Renew the passport" => :urgent}}.each do |type, priorities|
  priorities.each { |title, priority| type.owned_by(demo_user).find_by(title:)&.update!(priority:) }
end

# Things in the trash.
#
# One of each kind, at a different age (the task is close to its 30 days), so
# the trash page and the sidebar count have something to show. Each run trashes
# them again, so their ages start over.
[
  [Planner::Event, {title: "Old team lunch", day: Date.current - 4, start_time: "12:30", end_time: "14:00"}, 3.days],
  [Planner::Task, {title: "Return the parcel", day: Date.current - 9}, 26.days],
  [Planner::Todo, {title: "Learn the accordion"}, 1.day]
].each do |type, attrs, age|
  item = type.create!(attrs.merge(user: demo_user))
  item.entity.update_columns(deleted_at: Time.current - age)
end

# Events that repeat.
#
# One of each kind of rule, and a few of the states worth trying, to have fixed
# entries to edit and delete. The first days are relative to today.
zone = Core::EffectivePreferences.new(user: demo_user).time_zone
today = Date.current
monday = today.beginning_of_week
rule = Planner::Recurrence::Rule

# The second Tuesday of last month, where the book club rule starts from.
last_month = today.prev_month.beginning_of_month
second_tuesday = last_month + ((2 - last_month.wday) % 7) + 7

[
  {title: "Piano practice", starts_on: today - 7, rule: rule.new(frequency: "daily"), times: ["20:00", 30], tracks_done: 1},
  {title: "Team standup", starts_on: monday - 14, rule: rule.new(frequency: "weekly", weekdays: %w[MO WE FR]), times: ["09:00", 15]},
  {title: "Language course", starts_on: monday - 13, rule: rule.new(frequency: "weekly", weekdays: %w[TU], count: 8), times: ["18:30", 90]},
  {title: "Book club", starts_on: second_tuesday, rule: rule.new(frequency: "monthly", nth_weekday: "2TU"), times: ["19:00", 120]},
  {title: "Monthly report", starts_on: Date.new(today.year - 1, 12, 31), rule: rule.new(frequency: "monthly", month_day: 31)},
  {title: "Mom's birthday", starts_on: (today + 20).prev_year, rule: rule.for_anchor((today + 20).prev_year, frequency: "yearly")},
  {title: "Spanish lessons", starts_on: monday - 4, rule: rule.new(frequency: "weekly", weekdays: %w[TH]), times: ["17:00", 60], trashed: 2.days}
].each do |attrs|
  series = Planner::Series.create!(user: demo_user, time_zone: zone, title: attrs[:title], starts_on: attrs[:starts_on],
    rule: attrs[:rule], tracks_done: attrs.fetch(:tracks_done, 0)) do |record|
    record.start_time, record.duration_minutes = attrs[:times] if attrs[:times]
  end
  next unless attrs[:trashed]

  # Trashed the way the app does it, and then made older.
  Planner::Recurrence::Delete.new(series:, item: series.occurrence(series.starts_on), scope: "all").call
  series.update_columns(deleted_at: Time.current - attrs[:trashed])
end

# Piano practice has one occurrence done, one with notes of its own and one
# skipped. It has `tracks_done` enabled and started a week ago, so the first
# request of the day saves the other past occurrences as events, and the Missed
# events list shows them.
piano = Planner::Series.owned_by(demo_user).find_by!(title: "Piano practice")
yesterday = piano.materialize(today - 1)
yesterday.mark_done(true)
yesterday.save!
piano.materialize(today + 1).update!(notes: "Scales first.")
Planner::Recurrence::Delete.new(series: piano, item: piano.occurrence(today + 2), scope: "this").call
