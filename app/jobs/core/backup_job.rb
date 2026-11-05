# Copies the primary database, at most once a day.
#
# The directory and the number of copies that stay come from the environment
# (see Core::Backup).
class Core::BackupJob < ApplicationJob
  queue_as :background

  def perform = Core::Backup.once_a_day
end
