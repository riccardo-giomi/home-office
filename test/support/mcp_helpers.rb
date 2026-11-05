# Test tools for the endpoint tests: one that reads, one that writes (and says so if it is ever run), one that fails
class McpEchoTool < Core::Mcp::Tool
  tool_name "echo"
  description "Gives back what it was sent."
  access :read
  input_schema(properties: {text: {type: "string"}, kind: {type: "string", enum: %w[a b]}}, required: ["text"])

  def self.call(text:, server_context:, kind: nil)
    respond(echo: text, kind:, user: server_context[:user].email_address, zone: Time.zone.name, nothing: nil)
  end
end

class McpScribbleTool < Core::Mcp::Tool
  tool_name "scribble"
  description "Changes something."
  access :write
  input_schema(properties: {}, required: [])
  RUNS = []

  def self.call(server_context:)
    RUNS << server_context[:user].id
    respond(done: true)
  end
end

class McpBoomTool < Core::Mcp::Tool
  tool_name "boom"
  description "Always fails."
  access :read
  input_schema(properties: {}, required: [])

  def self.call(server_context:) = raise("secret internals #{server_context[:token].token_digest}")
end

class McpUndeclaredTool < Core::Mcp::Tool
  tool_name "undeclared"
  description "Says nothing about what it does."
  input_schema(properties: {}, required: [])

  def self.call(server_context:) = respond(ran: true)
end

module McpHelpers
  JSON_HEADERS = {"Content-Type" => "application/json", "Accept" => "application/json, text/event-stream"}.freeze
  TOOLS = [McpEchoTool, McpScribbleTool, McpBoomTool, McpUndeclaredTool].freeze

  include McpTokens

  def self.included(base)
    base.class_eval do
      before do
        @saved_modules = Core::Modules.all
        Core::Modules.register(Core::ModuleManifest.new(name: "mcp_test", mcp_tools: TOOLS))
        McpScribbleTool::RUNS.clear
      end
      after do
        Core::Modules.reset!
        @saved_modules.each { |manifest| Core::Modules.register(manifest) }
      end
    end
  end

  def rpc(method, params = nil, id: 1) = {jsonrpc: "2.0", id:, method:, params:}.compact

  # Posts one JSON-RPC message as the token; the answer is `rpc_body`
  def mcp_post(token, message, headers: {})
    body = message.is_a?(String) ? message : message.to_json
    auth = token ? bearer(token) : {}
    post mcp_path, params: body, headers: JSON_HEADERS.merge(auth).merge(headers)
  end

  def rpc_body = JSON.parse(response.body)

  def call_tool(token, name, arguments = {}, id: 1) = mcp_post(token, rpc("tools/call", {name:, arguments:}, id:))

  def tool_names(token)
    mcp_post(token, rpc("tools/list"))
    rpc_body.dig("result", "tools").map { |tool| tool["name"] }
  end

  # What a tool answered: its text parsed as JSON
  def tool_data = JSON.parse(rpc_body.dig("result", "content", 0, "text"))
end
