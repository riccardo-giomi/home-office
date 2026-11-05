# The tools that a token may use.
#
# Every tool of every module, or only the tools that read for a read-only token.
module Core::Mcp::Registry
  def self.tools_for(token)
    tools = Core::Modules.mcp_tools
    token.read_only? ? tools.select(&:read_only?) : tools
  end
end
