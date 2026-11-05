# The Settings page: a card for each group of related options.
#
# E.g. MCP tokens, preferences.
class SettingsController < ApplicationController
  def show
    @token_count = Current.user.mcp_tokens.count
  end
end
