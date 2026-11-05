# What every MCP tool of a module extends.
#
# A tool says once whether it reads or writes, with `access :read` or
# `access :write`. That sets the annotations that clients see, and it decides
# who may use the tool: a read-only token is given the tools that read, and a
# tool that does not say counts as one that writes.
#
# Tools are thin: they call the models and services that the controllers use, always
# through `server_context[:user]`.
class Core::Mcp::Tool < MCP::Tool
  class << self
    def access(kind)
      raise ArgumentError, "access is :read or :write" unless %i[read write].include?(kind)

      @access = kind
      annotations(read_only_hint: kind == :read, destructive_hint: false, idempotent_hint: false, open_world_hint: false)
    end

    # Returns :read or :write, or nil for a tool that never said.
    def access_kind = @access

    def read_only? = @access == :read

    # The answer of a tool: compact JSON in one text block.
    #
    # Nulls are dropped, so an agent pays only for what is there.
    def respond(data) = MCP::Tool::Response.new([{type: "text", text: JSON.generate(compacted(data))}])

    # An error that the agent can act on.
    #
    # The message says what was wrong and what would have been valid.
    def fail(message) = MCP::Tool::Response.new([{type: "text", text: message}], error: true)

    private

    def compacted(value)
      case value
      when Hash then value.compact.transform_values { |inner| compacted(inner) }
      when Array then value.map { |inner| compacted(inner) }
      else value
      end
    end
  end
end
