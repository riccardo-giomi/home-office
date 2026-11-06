require "test_helper"

# What a public repository must not contain. The checks need a checkout, which
# a Docker build does not have.
describe "the repository" do
  git = Rails.root.join(".git").exist?

  def ignored?(path) = system("git", "check-ignore", "-q", path, chdir: Rails.root.to_s)

  private_paths = %w[
    backup.sqlite3 production.sqlite3 storage/production.sqlite3 storage/backups/x.sqlite3
    config/master.key config/credentials/production.key .env .env.production log/production.log tmp/cache/x
  ]

  private_paths.each do |path|
    it "ignores #{path}" do
      skip "no .git directory" unless git
      assert ignored?(path), "#{path} is not ignored"
    end
  end
end
