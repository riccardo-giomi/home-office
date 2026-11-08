# The version of the application, from the VERSION file in the root.
#
# The file holds one line, a Semantic Versioning number such as `0.1.0`. The tag
# of a release has the same number with a `v` in front.
Rails.application.configure do
  config.x.version = Rails.root.join("VERSION").read.strip.freeze
end
