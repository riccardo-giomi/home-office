require "test_helper"
require "tmpdir"

describe Core::Backup do
  before do
    @dir = Pathname(Dir.mktmpdir)
    @database = @dir.join("source.sqlite3")
    @backups = @dir.join("backups")
    SQLite3::Database.new(@database.to_s) do |db|
      db.execute("CREATE TABLE notes (body TEXT)")
      db.execute("INSERT INTO notes VALUES ('first')")
    end
  end

  after do
    @backups.chmod(0o755) if @backups.exist?
    @dir.rmtree
  end

  def backup(now: Time.utc(2026, 3, 10, 3, 0, 0), **options)
    Core::Backup.call(directory: @backups, database: @database, now:, **options)
  end

  def sql_result(path, sql)
    db = SQLite3::Database.new(path.to_s)
    db.execute(sql)
  ensure
    db&.close
  end

  def rows(path) = sql_result(path, "SELECT body FROM notes").flatten

  it "writes a copy that passes its integrity check and holds the rows" do
    path = backup
    _(path.basename.to_s).must_equal "test-20260310-030000.sqlite3"
    _(rows(path)).must_equal ["first"]
    _(sql_result(path, "PRAGMA integrity_check")).must_equal [["ok"]]
  end

  it "does not hold what is written after it" do
    path = backup
    SQLite3::Database.new(@database.to_s) { |db| db.execute("INSERT INTO notes VALUES ('later')") }
    _(rows(path)).must_equal ["first"]
  end

  it "keeps the newest copies and removes the older ones, touching nothing else" do
    @backups.mkpath
    @backups.join("notes.txt").write("mine")
    3.times { |i| backup(now: Time.utc(2026, 3, 1 + i), keep: 2) }
    _(@backups.children.map { |file| file.basename.to_s }.sort).must_equal %w[notes.txt test-20260302-000000.sqlite3 test-20260303-000000.sqlite3]
  end

  it "raises and leaves the older copies when it cannot write" do
    old = backup(now: Time.utc(2026, 3, 1))
    @backups.chmod(0o555)
    skip "root ignores file modes" if Process.uid.zero?
    _ { backup(now: Time.utc(2026, 3, 2)) }.must_raise StandardError
    _(old).must_be :exist?
  end

  it "removes a leftover partial copy from a crash" do
    @backups.mkpath
    @backups.join("test-20260301-000000.sqlite3.partial").write("half")
    backup
    _(@backups.glob("*.partial")).must_be :empty?
  end

  it "does not overwrite a copy of the same second" do
    first = backup
    error = _ { backup }.must_raise(RuntimeError)
    _(error.message).must_match(/already exists/)
    _(rows(first)).must_equal ["first"]
  end

  it "refuses to keep fewer than one copy" do
    _ { backup(keep: 0) }.must_raise ArgumentError
  end

  describe "one a day" do
    def taken?(now: Time.utc(2026, 3, 10, 12, 0, 0)) = Core::Backup.new(directory: @backups, database: @database, now:).taken_today?

    def touch(name)
      @backups.mkpath
      @backups.join(name).write("")
    end

    it "has not been taken in an empty or missing directory" do
      _(taken?).must_equal false
      @backups.mkpath
      _(taken?).must_equal false
    end

    it "counts a backup of today (UTC), whatever the hour" do
      touch "test-20260310-000001.sqlite3"
      _(taken?).must_equal true
    end

    it "does not count yesterday, another environment, or a half-written copy" do
      touch "test-20260309-235959.sqlite3"
      touch "development-20260310-030000.sqlite3"
      touch "test-20260310-030000.sqlite3.partial"
      _(taken?).must_equal false
    end

    it "changes day at midnight UTC" do
      touch "test-20260309-235900.sqlite3"
      _(taken?(now: Time.utc(2026, 3, 10, 0, 1, 0))).must_equal false
    end

    it "once_a_day writes the first backup of a day and leaves the day alone after that" do
      first = Core::Backup.once_a_day(directory: @backups, database: @database, now: Time.utc(2026, 3, 10, 3, 0, 0))
      _(first.basename.to_s).must_equal "test-20260310-030000.sqlite3"
      _(Core::Backup.once_a_day(directory: @backups, database: @database, now: Time.utc(2026, 3, 10, 4, 0, 0))).must_be_nil
      _(@backups.glob("*.sqlite3").size).must_equal 1
    end

    it "still lets a manual backup write a second file the same day" do
      backup
      backup(now: Time.utc(2026, 3, 10, 3, 0, 1))
      _(@backups.glob("*.sqlite3").size).must_equal 2
    end
  end
end
