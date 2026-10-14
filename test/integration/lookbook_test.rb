class LookbookTest < ActionDispatch::IntegrationTest
  it "is mounted in test" do
    get "/lookbook"
    assert_response :not_found
  end
end
