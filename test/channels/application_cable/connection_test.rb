require "test_helper"

class ApplicationCable::ConnectionTest < ActionCable::Connection::TestCase
  it "connects a signed-in user under strict loading" do
    session = users(:admin).sessions.create!
    cookies.signed[:session_id] = session.id
    connect
    _(connection.current_user).must_equal users(:admin)
  end

  it "refuses an anonymous connection" do
    assert_reject_connection { connect }
  end
end
