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

# A few events around today so the list has something to show
[
  {title: "Dentist", days: 2, times: %w[09:30 10:15]},
  {title: "Team lunch", days: 5, times: %w[12:30 14:00]},
  {title: "Planning", days: 0, times: %w[10:00 11:30], tracks_done: true},
  {title: "Code review", days: 0, times: %w[10:30 11:00], tracks_done: true, state: "abandoned"},
  {title: "Call with the client", days: 0, times: %w[11:00 12:00], tracks_done: true},
  {title: "Gym", days: 0, times: %w[18:00 19:00], tracks_done: true},
  {title: "Pay the rent", days: 9, tracks_done: 1},
  {title: "Rent paid last month", days: -20, tracks_done: 1, done: true}
].each do |attrs|
  Planner::Event.create!(user: demo_user, title: attrs[:title]) do |event|
    event.assign_attributes(day: Date.current + attrs[:days], tracks_done: attrs.fetch(:tracks_done, 0), state: attrs.fetch(:state, "active"))
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
