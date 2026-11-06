require "test_helper"

# The path of a request through a proxy: the proxy sets `Host` to the name that
# it uses inside, and the public address reaches Rails only through the
# X-Forwarded-* headers.
class McpBehindProxyTest < ActionDispatch::IntegrationTest
  include McpTokens

  def tools_list(origin: nil)
    headers = {"Content-Type" => "application/json", "Accept" => "application/json, text/event-stream",
               "Host" => "app.internal", "X-Forwarded-Host" => "planner.example.com", "X-Forwarded-Proto" => "https"}
    headers["Origin"] = origin if origin
    post mcp_path, params: {jsonrpc: "2.0", id: 1, method: "tools/list"}.to_json,
      headers: headers.merge(bearer("member_write")), env: {"REMOTE_ADDR" => "172.18.0.2"}
  end

  it "takes the public address as the origin" do
    tools_list(origin: "https://planner.example.com")
    assert_response :success
  end

  it "turns away another origin, and the inside name, and takes a request with none" do
    tools_list(origin: "https://evil.example")
    assert_response :forbidden
    tools_list(origin: "http://app.internal")
    assert_response :forbidden
    tools_list
    assert_response :success
  end
end
