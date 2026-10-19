# Demo data, development-only.
# Running `bin/rails db:seed` again gives the same data with fresh dates.
# Add records below this guard, test/seeds_test.rb is watching you...
return unless Rails.env.development?

{"demo-admin@example.com" => :admin, "demo-user@example.com" => :user}.each do |email, role|
  User.find_or_create_by!(email_address: email) { |user| user.assign_attributes(role:, password: "development-only-password") }
end

demo_user = User.find_by!(email_address: "demo-user@example.com")
# The demo records are made again on every run, so their dates stay around today. Anything else the demo user made goes too.
Planner::Event.owned_by(demo_user).destroy_all

# A few events around today so the list has something to show
[
  {title: "Dentist", days: 2, times: %w[09:30 10:15]},
  {title: "Team lunch", days: 5, times: %w[12:30 14:00]},
  {title: "Planning", days: 0, times: %w[10:00 11:30], tracks_done: true},
  {title: "Code review", days: 0, times: %w[10:30 11:00], tracks_done: true},
  {title: "Call with the client", days: 0, times: %w[11:00 12:00], tracks_done: true},
  {title: "Gym", days: 0, times: %w[18:00 19:00], tracks_done: true},
  {title: "Pay the rent", days: 9, tracks_done: 1},
  {title: "Rent paid last month", days: -20, tracks_done: 1, done: true}
].each do |attrs|
  Planner::Event.create!(user: demo_user, title: attrs[:title]) do |event|
    event.assign_attributes(day: Date.current + attrs[:days], tracks_done: attrs.fetch(:tracks_done, 0))
    event.start_time, event.end_time = attrs[:times] if attrs[:times]
    event.mark_done(true) if attrs[:done]
  end
end
