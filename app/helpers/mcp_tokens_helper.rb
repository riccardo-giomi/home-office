module McpTokensHelper
  # The lines under the name of a token: what it may do, when it was made and
  # when it was last used.
  def token_detail(token)
    access = token.read_only? ? t("mcp_tokens.access.read_only") : t("mcp_tokens.access.read_write")
    last_used = token.last_used_at ? format_datetime(token.last_used_at) : t("mcp_tokens.index.never_used")
    safe_join([
      tag.span(t("mcp_tokens.index.access_line", access:), class: "block"),
      tag.span(safe_join([t("mcp_tokens.index.created"), ": ", format_datetime(token.created_at)]), class: "block"),
      tag.span(safe_join([t("mcp_tokens.index.last_used"), ": ", last_used]), class: "block")
    ])
  end
end
