# The address a request came from, for counting requests.
#
# Rails reads the client address from X-Forwarded-For whoever sends it. A
# caller that reaches the application directly could send a different address
# in each request and never reach a limit.
#
# This concern uses the header only when the connection comes from a proxy that
# Rails trusts by default (a private or loopback address). Otherwise it uses
# the address of the connection.
module Core::ClientAddress
  extend ActiveSupport::Concern

  private

  def client_address
    from_proxy = ActionDispatch::RemoteIp::TRUSTED_PROXIES.any? { |proxy| proxy === request.remote_addr }
    from_proxy ? request.remote_ip : request.remote_addr
  end
end
