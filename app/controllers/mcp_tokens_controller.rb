# The access tokens of the user for the MCP endpoint: made, listed and revoked.
#
# The text of a token is shown once, by the page that answers its creation, and
# kept nowhere.
class McpTokensController < ApplicationController
  def index
    @tokens = Current.user.mcp_tokens.order(:name)
  end

  def new
    @token = Core::McpToken.new
  end

  def create
    attributes = token_params.to_h.symbolize_keys.slice(:name, :read_only).with_defaults(name: "", read_only: false)
    @token = Core::McpToken.generate_for(Current.user, **attributes)
    if @token.persisted?
      # Not a redirect: this page holds the only copy of the token, and nothing
      # may keep it.
      response.headers["Cache-Control"] = "no-store"
      render :created
    else
      render :new, status: :unprocessable_content
    end
  end

  def destroy
    token = Current.user.mcp_tokens.find(params[:id])
    token.destroy!
    redirect_to mcp_tokens_path, notice: t(".revoked", name: token.name), status: :see_other
  end

  private

  def token_params = params.expect(core_mcp_token: [:name, :read_only])
end
