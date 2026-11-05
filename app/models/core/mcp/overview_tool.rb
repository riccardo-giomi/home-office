# The state of the plans of the user in one answer.
#
# The numbers of the cards of the home page, and the short lists that each
# module offers for what needs a look.
class Core::Mcp::OverviewTool < Core::Mcp::Tool
  tool_name "overview"
  description "Start here. Today's date, the counts of the home page (events, tasks, todos, trash) and short lists of what needs a look: today, important, missed, forgotten. Empty lists are left out."
  access :read
  input_schema(properties: {}, additionalProperties: false)

  def self.call(server_context:)
    user = server_context[:user]
    today = Date.current
    cards = Core::Modules.dashboard_cards(user, today:).map do |card|
      {
        title: I18n.t(card.title_key), total: card.total,
        lines: card.lines.map { |line| {label: I18n.t(line.label_key, count: line.count), count: line.count} }
      }
    end
    modules = Core::Modules.mcp_overview(user, today:).reject { |_, value| value.blank? }
    respond({today: today.iso8601, time_zone: Time.zone.name, cards:}.merge(modules))
  end
end
