# A date a series skips.
#
# It is an occurrence of a recurring events series that was deleted on its own.
#
# The skip outlives the occurrence's row, so the ghost of a purged row does not
# come back.
class Planner::SeriesExclusion < ApplicationRecord
  belongs_to :series, class_name: "Planner::Series", inverse_of: :exclusions

  validates :excluded_on, presence: true
end
