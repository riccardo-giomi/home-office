require "test_helper"
require "rake"
require "tmpdir"

describe "home_office:backup" do
  before do
    Rails.application.load_tasks unless Rake::Task.task_defined?("home_office:backup")
    Rake::Task["home_office:backup"].reenable
  end

  it "writes a backup into the directory from the environment and prints its path" do
    Dir.mktmpdir do |dir|
      ENV["HOME_OFFICE_BACKUP_DIR"] = dir
      out, = capture_io { Rake::Task["home_office:backup"].invoke }
      path = out.strip
      assert path.start_with?(dir)
      assert File.exist?(path)
    end
  ensure
    ENV.delete("HOME_OFFICE_BACKUP_DIR")
  end
end
