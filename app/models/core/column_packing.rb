# Organizes calendar entries that belong to a single day so that those that
# overlap get distributed in up to 4 columns, side-by-side. The rest is treated
# as "overflow" to avoid entries too small to read.
#
# "Interval-graph coloring", greedy answer: sorted by start, each entry takes the first column
# that is free.
#
# What cannot be fit in 4 columns (our "colors"), is returned as Result.overflow.
module Core::ColumnPacking
  MIN_MINUTES = 30
  MAX_COLUMNS = 4

  # Reads as:
  # Entry :entry from :from to :to fits in column :column of :columns, in "sub-group" :cluster. E.g.
  # Entry "1" from <start> to <end> fits in column 1 of 4, in "sub-group" 3.
  #
  # A sub-group contains all entries that are part of a
  # chain and share the same number of columns. Will come in handy building
  # sub-grids in the views.
  Placement = Struct.new(:entry, :from, :to, :column, :columns, :cluster)
  Result = Struct.new(:placements, :overflow)
  Cluster = Struct.new(:members, :latest_end)

  def self.call(entries)
    placements = entries.each_with_index
      .map { |entry, index| [Placement.new(entry, entry.from, [entry.to, entry.from + MIN_MINUTES].max), index] }
      .sort_by { |placement, index| [placement.from, -placement.to, index] }
      .map(&:first)

    overflow = []
    placed = clusters(placements).flat_map.with_index { |cluster, number| place(cluster, number, overflow) }
    Result.new(placed, overflow.sort_by { |entry| [entry.from, entry.to] })
  end

  # Organizes entries that overlap in clusters, "overlapping" means an entry
  # starts before the latest end of the entries already in the cluster.
  def self.clusters(placements)
    placements.each_with_object([]) do |placement, clusters|
      if clusters.any? && placement.from < clusters.last.latest_end
        clusters.last.members << placement
        clusters.last.latest_end = [clusters.last.latest_end, placement.to].max
      else
        clusters << Cluster.new([placement], placement.to)
      end
    end.map(&:members)
  end

  # Try to fit as much as possible in MAX_COLUMNS columns, put everything else
  # in overflow.
  def self.place(cluster, number, overflow)
    ends = []
    kept = cluster.filter_map do |placement|
      column = ends.index { |ended| ended <= placement.from } || ends.size
      if column >= MAX_COLUMNS
        overflow << placement.entry
        next
      end
      ends[column] = placement.to
      placement.column = column
      placement.cluster = number
      placement
    end
    kept.each { |placement| placement.columns = ends.size }
  end

  private_class_method :clusters, :place
end
