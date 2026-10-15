require "test_helper"

class PasswordResetRemovedTest < ActionDispatch::IntegrationTest
  it "has no password reset page" do
    get "/passwords/new"
    assert_response :not_found
  end
end
