# The MCP endpoint: JSON-RPC over a POST, answered with plain JSON.
#
# There are no sessions and no streams. The bearer token names the user and
# decides which tools exist for the request.
#
# It is an API controller on purpose: no cookies, no CSRF token, no browser
# checks. The token is the only way in.
class McpController < ActionController::API
  MAX_BODY = 256.kilobytes
  MAX_NESTING = 32

  rate_limit to: 120, within: 1.minute, by: -> { presented_digest || request.remote_ip },
    with: -> { rpc_error(429, -32000, "Too many requests. Wait a minute and try again.") }
  before_action :reject_foreign_origin, :authenticate_token

  def create
    message = read_message or return
    answer = Core::Mcp::RequestContext.run(@token.user) { server.handle(message) }
    answer ? render(json: answer) : head(:accepted)
  end

  # The endpoint takes only POST.
  def unsupported
    response.headers["Allow"] = "POST"
    rpc_error(405, -32600, "Use POST.")
  end

  private

  def server
    MCP::Server.new(
      name: "home-office", version: "1.0.0",
      tools: Core::Mcp::Registry.tools_for(@token),
      server_context: {user: @token.user, token: @token},
      instructions: "Home Office: the user's events, tasks and todos. Start with the overview tool. " \
        "Times are local to the user's time zone, dates ISO 8601. Deleting only moves things to the trash."
    )
  end

  # Returns the message as a hash, or nil after answering why not.
  def read_message
    raw = request.body.read(MAX_BODY + 1).to_s
    return rpc_error(413, -32600, "The request is too large.") && nil if raw.bytesize > MAX_BODY

    message = JSON.parse(raw, max_nesting: MAX_NESTING)
    return message.deep_symbolize_keys if message.is_a?(Hash)

    rpc_error(400, -32600, "Send one JSON-RPC message as a JSON object.") && nil
  rescue JSON::ParserError
    rpc_error(400, -32700, "The request is not valid JSON.") && nil
  end

  # Agents send no Origin. A browser page from another site does, and it must
  # not use the token of a user.
  def reject_foreign_origin
    origin = request.headers["Origin"]
    rpc_error(403, -32600, "Origin not allowed.") if origin.present? && origin != request.base_url
  end

  def authenticate_token
    @token = Core::McpToken.authenticate(presented_token)
    return unauthorized unless @token

    @token.touch_last_used
  end

  def presented_token = request.authorization.to_s[/\ABearer (\S+)\z/i, 1]

  def presented_digest = (Core::McpToken.digest(presented_token) if presented_token)

  def unauthorized
    response.headers["WWW-Authenticate"] = 'Bearer realm="Home Office"'
    rpc_error(401, -32001, "A valid access token is needed.")
  end

  def rpc_error(status, code, message)
    render json: {jsonrpc: "2.0", id: nil, error: {code:, message:}}, status:
  end
end
