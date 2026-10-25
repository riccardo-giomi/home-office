# Counting the queries a request asks about items.
#
# It proves that a page does not grow with its data.
module QueryCounting
  # The queries that read rows of planner_items.
  #
  # COUNT queries (such as a badge's) and repeats answered by the request's
  # query cache are not counted.
  def planner_item_selects(&block)
    queries = []
    callback = ->(*, payload) { queries << payload[:sql] if !payload[:cached] && payload[:sql].match?(/\ASELECT "planner_items"\.\*/m) }
    ActiveSupport::Notifications.subscribed(callback, "sql.active_record", &block)
    queries
  end

  # Every reading query a block asks.
  #
  # Repeats answered by the query cache and the schema and transaction
  # statements are not counted.
  def selects(&block)
    queries = []
    callback = ->(*, payload) { queries << payload[:sql] if !payload[:cached] && payload[:name] != "SCHEMA" && payload[:sql].start_with?("SELECT") }
    ActiveSupport::Notifications.subscribed(callback, "sql.active_record", &block)
    queries
  end
end
