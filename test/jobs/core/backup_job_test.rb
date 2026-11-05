require "test_helper"

describe Core::BackupJob do
  it "takes the day's backup, with no arguments" do
    original = Core::Backup.method(:once_a_day)
    called = nil
    Core::Backup.define_singleton_method(:once_a_day) { |**args| called = args }
    Core::BackupJob.perform_now
    _(called).must_equal({})
  ensure
    Core::Backup.define_singleton_method(:once_a_day, original)
  end
end
