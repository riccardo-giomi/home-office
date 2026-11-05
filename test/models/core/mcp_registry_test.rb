require "test_helper"

# The tools every module really offers (no test tools): who may use them, how they are described, what they cost to list
describe "the MCP tools of the application" do
  let(:tools) { Core::Modules.mcp_tools }
  let(:writers) { tools.reject(&:read_only?) }

  it "are these nine" do
    _(tools.map(&:name_value)).must_equal %w[overview list_items get_item create_item update_items trash_items restore_items link_items unlink_items]
  end

  it "have a name that is snake_case and short, and a name nobody else has" do
    names = tools.map(&:name_value)
    _(names.uniq).must_equal names
    names.each do |name|
      _(name).must_match(/\A[a-z]+(_[a-z]+)*\z/)
      _(name.size).must_be :<=, 24
    end
  end

  it "each say whether they read or write" do
    tools.each { |tool| _(%i[read write]).must_include tool.access_kind, tool.name_value }
  end

  it "state what they do to the client: reads are read-only, nothing is destructive or reaches outside" do
    tools.each do |tool|
      hints = tool.to_h.fetch(:annotations)
      _(hints[:readOnlyHint]).must_equal(tool.read_only?, tool.name_value)
      _(hints[:destructiveHint]).must_equal false
      _(hints[:openWorldHint]).must_equal false
    end
  end

  it "are given to a read-only token only if they read, and to a write token all" do
    read_token = core_mcp_tokens(:member_read)
    write_token = core_mcp_tokens(:member_write)
    _(Core::Mcp::Registry.tools_for(read_token).map(&:name_value)).must_equal %w[overview list_items get_item]
    _(Core::Mcp::Registry.tools_for(write_token)).must_equal tools
  end

  it "that change things are the six that write, and the only ones that may" do
    _(writers.map(&:name_value)).must_equal %w[create_item update_items trash_items restore_items link_items unlink_items]
  end

  it "refuse arguments they do not know, so a typo is an error and not a silent no-op" do
    tools.each do |tool|
      schema = tool.input_schema_value.to_h
      _(schema[:additionalProperties]).must_equal false, tool.name_value
    end
  end

  it "keep their descriptions short, because agents pay for them in every session" do
    tools.each do |tool|
      _(tool.description_value.size).must_be :<, 330, tool.name_value
      tool.input_schema_value.to_h.fetch(:properties).each_value do |property|
        _(property[:description].to_s.size).must_be :<, 200
      end
    end
  end

  it "cost less than 9 000 bytes to list" do
    _(tools.sum { |tool| tool.to_h.to_json.bytesize }).must_be :<, 9_000
  end
end

describe "access tokens" do
  it "stay hashed: no stored digest looks like a token" do
    _(Core::McpToken.pluck(:token_digest)).wont_be_empty
    Core::McpToken.pluck(:token_digest).each { |digest| _(digest).wont_match(/\Aho_/) }
  end
end
