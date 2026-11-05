# A tool that raises is not answered with the message of the error: the gem
# hides it. It goes to the error reporter instead.
MCP.configure do |config|
  config.exception_reporter = lambda do |error, context|
    Rails.error.report(error, handled: true, source: "mcp", context: {tool: context[:tool_name]})
  end
end
