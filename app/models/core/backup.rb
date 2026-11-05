# A copy of the primary database that is consistent while the application runs.
#
# `VACUUM INTO` writes the copy, so it never holds half of a write. The copy is
# written under a temporary name, checked with `PRAGMA integrity_check` and
# then renamed, so a copy that was not finished never counts as a backup. Older
# copies are removed only after the new one is good.
class Core::Backup
  def self.call(**) = new(**).call

  # What the scheduled job runs: a day that has a backup (a manual one counts)
  # gets no second one. Returns nil in that case.
  def self.once_a_day(**)
    backup = new(**)
    backup.call unless backup.taken_today?
  end

  # `directory` is where the copies go, `keep` is the number of copies that
  # stay, `now` names the copy, and `database` is the file to copy. Their
  # defaults come from `HOME_OFFICE_BACKUP_DIR` (`storage/backups`),
  # `HOME_OFFICE_BACKUP_KEEP` (14) and the database configuration.
  def initialize(directory: ENV["HOME_OFFICE_BACKUP_DIR"].presence || "storage/backups",
    keep: Integer(ENV["HOME_OFFICE_BACKUP_KEEP"].presence || 14), now: Time.current,
    database: ActiveRecord::Base.connection_db_config.database)
    raise ArgumentError, "keep must be at least 1" if keep < 1

    @directory, @keep, @now = Rails.root.join(directory), keep, now
    @database = Rails.root.join(database)
  end

  # Writes the copy and returns its path. Raises if the copy cannot be written
  # or fails the check; the older copies stay then.
  def call
    @directory.mkpath
    @directory.glob("*.partial").each(&:delete)
    target = @directory.join("#{Rails.env}-#{@now.utc.strftime("%Y%m%d-%H%M%S")}.sqlite3")
    raise "#{target} already exists" if target.exist?

    partial = Pathname("#{target}.partial")
    copy(partial)
    partial.rename(target)
    prune
    target
  rescue
    partial.delete if partial&.exist?
    raise
  end

  # Whether a copy of the current environment exists for the day of `now`, in
  # UTC.
  def taken_today? = @directory.glob("#{Rails.env}-#{@now.utc.strftime("%Y%m%d")}-*.sqlite3").any?

  private

  def copy(partial)
    SQLite3::Database.new(@database.to_s) do |db|
      db.busy_timeout = 5000
      db.execute("VACUUM INTO ?", [partial.to_s])
    end
    SQLite3::Database.new(partial.to_s) do |db|
      result = db.get_first_value("PRAGMA integrity_check")
      raise "Backup failed its integrity check: #{result}" unless result == "ok"
    end
  end

  def prune
    @directory.glob("#{Rails.env}-*.sqlite3").sort.reverse.drop(@keep).each(&:delete)
  end
end
