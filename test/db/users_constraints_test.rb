require "test_helper"

describe "users and sessions constraints" do
  let(:connection) { ActiveRecord::Base.connection }

  def insert_user(email: "new@example.com", role: "user")
    connection.execute(<<~SQL)
      INSERT INTO users (email_address, password_digest, role, created_at, updated_at)
      VALUES ('#{email}', 'digest', '#{role}', '2026-01-01', '2026-01-01')
    SQL
  end

  it "rejects an email that is not trimmed and lower case" do
    _ { insert_user(email: "New@Example.com") }.must_raise ActiveRecord::StatementInvalid
  end

  it "rejects an unknown role" do
    _ { insert_user(role: "boss") }.must_raise ActiveRecord::StatementInvalid
  end

  it "rejects a duplicate email" do
    _ { insert_user(email: users(:admin).email_address) }.must_raise ActiveRecord::StatementInvalid
  end

  it "deletes sessions with their user at the database level" do
    user = users(:member)
    user.sessions.create!
    connection.execute("DELETE FROM users WHERE id = #{user.id}")
    _(Session.where(user_id: user.id)).must_be_empty
  end

  it "destroys a user together with its sessions under strict loading" do
    user = users(:member)
    user.sessions.create!
    assert_difference "Session.count", -1 do
      user.destroy
    end
  end
end
