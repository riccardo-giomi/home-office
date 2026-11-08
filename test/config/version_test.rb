require "test_helper"

describe "the version of the application" do
  # Semantic Versioning 2.0.0: major.minor.patch, and an optional pre-release.
  semver = /\A(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)(-[0-9A-Za-z-]+(\.[0-9A-Za-z-]+)*)?\z/

  it "is a Semantic Versioning number" do
    _(Rails.configuration.x.version).must_match semver
  end

  it "is the content of the VERSION file" do
    _(Rails.configuration.x.version).must_equal Rails.root.join("VERSION").read.strip
  end
end
