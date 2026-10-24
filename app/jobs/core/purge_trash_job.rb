# Purges the trash.
#
# Hard-deletes what has sat in the trash past its time. The entities go, and the
# database cascade takes the records of every module with them. It runs often,
# so a computer that sleeps at night still purges.
class Core::PurgeTrashJob < ApplicationJob
  queue_as :background

  def perform = Core::Entity.purge_expired
end
