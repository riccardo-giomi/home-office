# Sends a message to the open home pages of a user when a number that they
# show may have changed.
#
# The message is a Turbo "refresh" on a stream of the user. It carries no
# numbers: the page that receives it requests the new numbers from the server.
#
# A module calls `refresh` when it changes something that a card counts, or
# wraps a bulk write in `announce`. A bulk write (`update_all`, `insert_all!`,
# `delete_all`) runs no callbacks, so no other code would send the message.
#
# Nothing is sent before the data is committed: a page that refreshed first
# would read the old numbers. The users are remembered in `Current`, so the
# writes of one transaction send one message for each user, not one for each
# write.
#
# The users are a set, not a single user. A request changes the data of the
# signed-in user, but a purge changes the data of several users in one pass, and
# a job has no signed-in user at all.
module Core::Overview
  # The streamables of the stream of a user, for `turbo_stream_from` and for the
  # tests.
  def self.stream(user_id) = ["overview", user_id]

  # Sends a refresh to the user once the open transactions have committed.
  #
  # The callback is registered on every call, because a transaction that is
  # rolled back drops it. Sending twice is harmless: the second call finds
  # no user left to send to.
  def self.refresh(user_id)
    (Current.overview_users ||= Set.new) << user_id
    ActiveRecord.after_all_transactions_commit { send_pending }
  end

  # Runs the block, which writes, and then sends the message. Returns what the
  # block returns, so it can wrap an expression.
  def self.announce(user_id)
    yield.tap { refresh(user_id) }
  end

  def self.send_pending
    users = Current.overview_users
    Current.overview_users = nil
    users&.each { |id| Turbo::StreamsChannel.broadcast_refresh_to(*stream(id)) }
  end
  private_class_method :send_pending
end
