require "test_helper"

describe Core::McpToken do
  let(:member) { users(:member) }

  describe ".generate_for" do
    it "makes a token of ho_ and 64 hex characters, keeping only its digest" do
      token = Core::McpToken.generate_for(member, name: "Laptop", read_only: false)
      _(token).must_be :persisted?
      _(token.plain).must_match(/\Aho_[0-9a-f]{64}\z/)
      _(token.token_digest).must_equal Digest::SHA256.hexdigest(token.plain)
      _(Core::McpToken.find(token.id).plain).must_be_nil
      _(Core::McpToken.where("token_digest LIKE ?", "%#{token.plain}%")).must_be :none?
    end

    it "makes a different token every time" do
      plains = Array.new(3) { |i| Core::McpToken.generate_for(member, name: "T#{i}", read_only: false).plain }
      _(plains.uniq.size).must_equal 3
    end

    it "keeps the read-only choice as 0 or 1" do
      _(Core::McpToken.generate_for(member, name: "R", read_only: true)).must_be :read_only?
      _(Core::McpToken.generate_for(member, name: "W", read_only: false)).wont_be :read_only?
      _(Core::McpToken.generate_for(member, name: "S", read_only: "1")).must_be :read_only?
      _(Core::McpToken.generate_for(member, name: "Z", read_only: "0")).wont_be :read_only?
    end

    it "answers a name that was taken a moment ago (a double click) as an invalid token, not an exception" do
      original = Core::McpToken.instance_method(:valid?)
      Core::McpToken.define_method(:valid?) { |*| true }
      token = Core::McpToken.generate_for(member, name: "Writer", read_only: false)
      _(token).wont_be :persisted?
      _(token.errors[:name]).wont_be :empty?
    ensure
      Core::McpToken.define_method(:valid?, original)
    end

    it "is not valid without a name, with a name over 60 characters, or with a name the user already has" do
      _(Core::McpToken.generate_for(member, name: " ", read_only: false).errors[:name]).wont_be :empty?
      _(Core::McpToken.generate_for(member, name: "x" * 61, read_only: false).errors[:name]).wont_be :empty?
      duplicate = Core::McpToken.generate_for(member, name: "Writer", read_only: false)
      _(duplicate).wont_be :persisted?
      _(duplicate.errors[:name]).wont_be :empty?
      _(Core::McpToken.generate_for(users(:admin), name: "Reader", read_only: false)).must_be :persisted?
    end
  end

  describe ".authenticate" do
    it "finds the token a plain text belongs to, with its user" do
      token = Core::McpToken.authenticate(McpTokens::PLAIN.fetch("member_read"))
      _(token).must_equal core_mcp_tokens(:member_read)
      _(token).must_be :read_only?
      _(token.user).must_equal member
    end

    it "gives nothing for text that is not a token" do
      ["", " ", nil, "ho_", "ho_#{"9" * 64}", McpTokens::PLAIN.fetch("member_read").upcase, "x" * 100_000, 5, []].each do |text|
        assert_nil Core::McpToken.authenticate(text), "accepted #{text.inspect[0, 20]}"
      end
    end

    it "gives nothing for the token of a deactivated user" do
      assert_nil Core::McpToken.authenticate(McpTokens::PLAIN.fetch("retired_write"))
    end
  end

  describe "#touch_last_used" do
    it "writes the moment once, then not again inside a minute" do
      token = core_mcp_tokens(:member_write)
      travel_to Time.utc(2026, 10, 11, 12, 0, 0) do
        token.touch_last_used
        _(token.reload.last_used_at).must_equal Time.utc(2026, 10, 11, 12, 0, 0)
      end
      travel_to Time.utc(2026, 10, 11, 12, 0, 59) do
        token.touch_last_used
        _(token.reload.last_used_at).must_equal Time.utc(2026, 10, 11, 12, 0, 0)
      end
      travel_to Time.utc(2026, 10, 11, 12, 1, 1) do
        token.touch_last_used
        _(token.reload.last_used_at).must_equal Time.utc(2026, 10, 11, 12, 1, 1)
      end
    end
  end
end

describe "tokens and users" do
  it "are deleted when the user is deactivated, and not given back on reactivation" do
    member = users(:member)
    _(member.mcp_tokens.count).must_equal 2
    _(member.deactivate).must_equal true
    _(Core::McpToken.where(user_id: member.id).count).must_equal 0
    member.reactivate
    _(Core::McpToken.where(user_id: member.id).count).must_equal 0
    _(Core::McpToken.where.not(user_id: member.id).count).must_equal 2
  end
end
