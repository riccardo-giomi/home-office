require "test_helper"

describe "core_mcp_tokens constraints" do
  let(:connection) { ActiveRecord::Base.connection }
  let(:digest) { "a" * 64 }

  def insert(user_id: users(:member).id, name: "Laptop", token_digest: digest, read_only: 0)
    connection.execute("INSERT INTO core_mcp_tokens (user_id, name, token_digest, read_only, created_at) VALUES (#{connection.quote(user_id)}, #{connection.quote(name)}, #{connection.quote(token_digest)}, #{connection.quote(read_only)}, '2026-01-01')")
  end

  it "keeps a digest of exactly 64 lowercase hex characters" do
    insert
    ["a" * 63, "a" * 65, "A" * 64, "g" * 64, "", ("a" * 63) + " "].each_with_index do |bad, index|
      _ { insert(name: "Bad #{index}", token_digest: bad) }.must_raise ActiveRecord::StatementInvalid, "accepted #{bad.inspect}"
    end
  end

  it "has a digest only once, in the whole table" do
    insert
    _ { insert(user_id: users(:admin).id, name: "Other") }.must_raise ActiveRecord::RecordNotUnique
  end

  it "has a name once for a user, and the same name for two users" do
    insert
    _ { insert(token_digest: "b" * 64) }.must_raise ActiveRecord::RecordNotUnique
    insert(user_id: users(:admin).id, token_digest: "c" * 64)
  end

  it "has read_only as 0 or 1, 0 by default" do
    _ { insert(read_only: 2) }.must_raise ActiveRecord::StatementInvalid
    _ { insert(read_only: nil) }.must_raise ActiveRecord::NotNullViolation
    connection.execute("INSERT INTO core_mcp_tokens (user_id, name, token_digest, created_at) VALUES (#{users(:member).id}, 'Default', '#{"d" * 64}', '2026-01-01')")
    _(connection.select_value("SELECT read_only FROM core_mcp_tokens WHERE name = 'Default'")).must_equal 0
  end

  it "needs an owner that exists, and goes with the owner" do
    _ { insert(user_id: 999_999) }.must_raise ActiveRecord::InvalidForeignKey
    insert
    member_id = users(:member).id
    users(:member).destroy!
    _(connection.select_value("SELECT COUNT(*) FROM core_mcp_tokens WHERE user_id = #{member_id}")).must_equal 0
  end
end
