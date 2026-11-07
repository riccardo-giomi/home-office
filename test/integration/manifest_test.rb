require "test_helper"

# The manifest describes the application to a browser that installs it.
class ManifestTest < ActionDispatch::IntegrationTest
  it "is served as JSON to a visitor who is not signed in" do
    get pwa_manifest_path(format: :json)

    assert_response :success
    assert_equal "application/json", response.media_type
    manifest = JSON.parse(response.body)
    assert_equal "Home Office", manifest["name"]
    assert_equal "/", manifest["start_url"]
  end

  it "points to icons that exist" do
    get pwa_manifest_path(format: :json)

    icons = JSON.parse(response.body).fetch("icons")
    assert_not_empty icons
    icons.each do |icon|
      assert Rails.public_path.join(icon["src"].delete_prefix("/")).file?, "#{icon["src"]} is not in public/"
    end
  end

  it "is linked from the pages" do
    get new_session_path

    assert_select "link[rel=manifest][href=?]", pwa_manifest_path(format: :json)
  end
end
