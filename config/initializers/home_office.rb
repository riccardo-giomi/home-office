# Option to delete users for good.
#
# Off unless the person running the app switches it on. An admin can then purge
# deactivated users and all their data.
Rails.application.configure do
  config.x.hard_delete_users = ENV["HOME_OFFICE_ENABLE_HARD_DELETE"].to_s.downcase.in?(%w[1 true])
end
