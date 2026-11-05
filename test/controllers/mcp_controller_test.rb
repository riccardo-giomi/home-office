require "test_helper"

class McpControllerTest < ActionDispatch::IntegrationTest
  include McpHelpers

  describe "who may come in" do
    it "turns away a request with no token, a wrong token and a deactivated user's token, saying only how to authenticate" do
      [nil, "wrong", "retired_write"].each do |token|
        headers = (token == "wrong") ? {"Authorization" => "Bearer ho_#{"9" * 64}"} : {}
        mcp_post((token == "wrong") ? nil : token, rpc("tools/list"), headers:)
        assert_response :unauthorized
        assert_match(/\ABearer/, response.headers["WWW-Authenticate"])
        assert_equal(-32001, rpc_body.dig("error", "code"))
        assert_no_match(/ho_[0-9a-f]{20}/, response.body)
      end
    end

    it "accepts only a Bearer header" do
      plain = McpTokens::PLAIN.fetch("member_write")
      [{"Authorization" => "Basic #{plain}"}, {"Authorization" => plain}, {"Authorization" => "Bearer"}, {"Authorization" => "Bearer #{plain} extra"}].each do |headers|
        mcp_post(nil, rpc("tools/list"), headers:)
        assert_response :unauthorized
      end
      post "/mcp?token=#{plain}", params: rpc("tools/list").to_json, headers: JSON_HEADERS
      assert_response :unauthorized
    end

    it "does not take the browser's session cookie" do
      sign_in_as users(:member)
      mcp_post(nil, rpc("tools/list"))
      assert_response :unauthorized
    end

    it "turns away a browser page from another origin, and lets through a request with no Origin" do
      mcp_post("member_write", rpc("tools/list"), headers: {"Origin" => "https://evil.example"})
      assert_response :forbidden
      mcp_post("member_write", rpc("tools/list"), headers: {"Origin" => "http://www.example.com"})
      assert_response :success
      mcp_post("member_write", rpc("tools/list"))
      assert_response :success
    end

    it "answers only POST" do
      get mcp_path, headers: bearer("member_write")
      assert_response :method_not_allowed
      assert_equal "POST", response.headers["Allow"]
      delete mcp_path, headers: bearer("member_write")
      assert_response :method_not_allowed
    end

    it "records when a token was used, once a minute at most" do
      token = core_mcp_tokens(:member_write)
      travel_to(Time.utc(2026, 10, 11, 12, 0, 0)) { mcp_post("member_write", rpc("tools/list")) }
      assert_equal Time.utc(2026, 10, 11, 12, 0, 0), token.reload.last_used_at
      travel_to(Time.utc(2026, 10, 11, 12, 0, 30)) { mcp_post("member_write", rpc("tools/list")) }
      assert_equal Time.utc(2026, 10, 11, 12, 0, 0), token.reload.last_used_at
    end

    it "does not record use for a request that was turned away" do
      mcp_post(nil, rpc("tools/list"), headers: {"Authorization" => "Bearer ho_#{"9" * 64}"})
      assert_nil core_mcp_tokens(:member_write).reload.last_used_at
    end
  end

  describe "the protocol" do
    it "answers initialize with what the server is and what it offers" do
      mcp_post("member_write", rpc("initialize", {protocolVersion: "2025-06-18", capabilities: {}, clientInfo: {name: "test", version: "1"}}))
      assert_response :success
      assert_equal "application/json", response.media_type
      result = rpc_body.fetch("result")
      assert_equal "home-office", result.dig("serverInfo", "name")
      assert_includes result.fetch("capabilities").keys, "tools"
      assert_operator result.fetch("instructions").size, :<, 600
    end

    it "answers a notification with 202 and no body" do
      mcp_post("member_write", {jsonrpc: "2.0", method: "notifications/initialized"})
      assert_response :accepted
      assert_empty response.body
    end

    it "lists the tools and calls one, as the token's user, in the user's time zone" do
      users(:member).update!(time_zone: "Pacific/Auckland")
      call_tool("member_write", "echo", {text: "hi"})
      assert_equal({"echo" => "hi", "user" => "member@example.com", "zone" => "Pacific/Auckland"}, tool_data)
    end

    it "leaves out null values from what a tool answers" do
      call_tool("member_write", "echo", {text: "hi"})
      refute_includes tool_data.keys, "nothing"
      refute_includes tool_data.keys, "kind"
    end

    it "says what would have been valid when an argument is wrong" do
      call_tool("member_write", "echo", {text: "hi", kind: "z"})
      assert rpc_body.dig("result", "isError")
      assert_match(/\/kind.*not one of: \["a", "b"\]/, rpc_body.dig("result", "content", 0, "text"))
      call_tool("member_write", "echo", {})
      assert rpc_body.dig("result", "isError")
      assert_match(/text/, rpc_body.dig("result", "content", 0, "text"))
    end

    it "answers an unknown tool as an error that names it" do
      call_tool("member_write", "nope")
      assert_match(/Tool not found: nope/, rpc_body.dig("error", "data"))
    end

    it "hides what went wrong inside a tool, and reports it" do
      reported = []
      subscriber = Class.new { define_method(:report) { |error, **| reported << error } }.new
      Rails.error.subscribe(subscriber)
      call_tool("member_write", "boom")
      assert_response :success
      assert_match(/Internal error/, rpc_body.dig("error", "message"))
      refute_match(/secret|#{core_mcp_tokens(:member_write).token_digest}/, response.body)
      assert reported.any? { |error| error.message.start_with?("secret internals") }
    ensure
      Rails.error.unsubscribe(subscriber)
    end

    it "answers bad JSON with a parse error, not a 500" do
      mcp_post("member_write", "{not json")
      assert_response :bad_request
      assert_equal(-32700, rpc_body.dig("error", "code"))
      mcp_post("member_write", "[]")
      assert_response :bad_request
      assert_equal(-32600, rpc_body.dig("error", "code"))
      mcp_post("member_write", "[1,2]")
      assert_response :bad_request
      mcp_post("member_write", "")
      assert_response :bad_request
    end

    it "refuses a body that is too large, and one nested too deep" do
      mcp_post("member_write", rpc("tools/list", {pad: "x" * 300_000}))
      assert_response :content_too_large
      mcp_post("member_write", ("[" * 200) + ("]" * 200))
      assert_response :bad_request
    end
  end

  describe "what each kind of token may use" do
    it "gives a write token every tool and a read-only token only those that change nothing" do
      ours = McpHelpers::TOOLS.map { |tool| tool.name_value }
      assert_equal ours.sort, (tool_names("member_write") & ours).sort
      assert_equal %w[boom echo], (tool_names("member_read") & ours).sort
    end

    it "treats a tool that did not say what it does as one that writes" do
      refute McpUndeclaredTool.read_only?
      refute_includes tool_names("member_read"), "undeclared"
    end

    it "states in every tool's annotations what it does, and that it reaches nothing outside" do
      mcp_post("member_write", rpc("tools/list"))
      rpc_body.dig("result", "tools").select { |tool| %w[echo scribble boom].include?(tool["name"]) }.each do |tool|
        annotations = tool.fetch("annotations")
        assert_equal false, annotations["openWorldHint"], tool["name"]
        assert_equal false, annotations["destructiveHint"], tool["name"]
        assert_equal %w[echo boom].include?(tool["name"]), annotations["readOnlyHint"], tool["name"]
      end
    end

    it "does not run a write tool for a read-only token, by name, and says it does not exist" do
      call_tool("member_read", "scribble")
      assert_match(/Tool not found: scribble/, rpc_body.dig("error", "data"))
      assert_empty McpScribbleTool::RUNS
      call_tool("member_write", "scribble")
      assert_equal [users(:member).id], McpScribbleTool::RUNS
    end
  end

  describe "limits" do
    it "answers the 121st request in a minute with 429, per token" do
      120.times { mcp_post("member_write", rpc("ping")) }
      assert_response :success
      mcp_post("member_write", rpc("ping"))
      assert_response :too_many_requests
      assert_equal(-32000, rpc_body.dig("error", "code"))
      mcp_post("admin_write", rpc("ping"))
      assert_response :success
    end

    it "counts requests with a wrong token against the text that was sent, not against everyone" do
      121.times { mcp_post(nil, rpc("ping"), headers: {"Authorization" => "Bearer ho_#{"8" * 64}"}) }
      assert_response :too_many_requests
      mcp_post("member_write", rpc("ping"))
      assert_response :success
    end
  end

  describe "the day starts where the user is" do
    it "runs the modules' catch-up for the user, with today in their zone" do
      seen = []
      Core::Modules.register(Core::ModuleManifest.new(name: "mcp_catch_up", catch_up: ->(user, today) { seen << [user.id, today] }))
      use_catch_up "lazy"
      users(:member).update!(time_zone: "Pacific/Auckland")
      travel_to(Time.utc(2026, 10, 11, 23, 30)) { mcp_post("member_write", rpc("tools/list")) }
      assert_equal [[users(:member).id, Date.new(2026, 10, 12)]], seen
    end

    it "leaves the catch-up to the job in job mode" do
      seen = []
      Core::Modules.register(Core::ModuleManifest.new(name: "mcp_catch_up", catch_up: ->(user, today) { seen << user.id }))
      use_catch_up "job"
      mcp_post("member_write", rpc("tools/list"))
      assert_empty seen
    end
  end
end
