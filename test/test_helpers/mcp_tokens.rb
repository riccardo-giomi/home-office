# The plain tokens behind the fixture rows (only their digests are stored), and a Bearer header for a request
module McpTokens
  PLAIN = {
    "member_write" => "ho_#{"1" * 64}",
    "member_read" => "ho_#{"2" * 64}",
    "admin_write" => "ho_#{"3" * 64}",
    "retired_write" => "ho_#{"4" * 64}"
  }.freeze

  def self.digest(label) = Digest::SHA256.hexdigest(PLAIN.fetch(label))

  def bearer(label) = {"Authorization" => "Bearer #{PLAIN.fetch(label)}"}
end
