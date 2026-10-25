module User::Preferences
  extend ActiveSupport::Concern

  DATE_FORMATS = %w[dmy mdy ymd].freeze
  TIME_FORMATS = %w[12h 24h].freeze
  THEMES = %w[light dark].freeze

  included do
    # A blank choice from a form means "automatic": store NULL, never an empty string.
    normalizes :locale, :date_format, :time_format, :time_zone, :theme, :detected_time_zone, with: ->(value) { value.presence }

    validates :locale, inclusion: {in: ->(_user) { I18n.available_locales.map(&:to_s) }}, allow_nil: true
    validates :date_format, inclusion: {in: DATE_FORMATS}, allow_nil: true
    validates :first_weekday, inclusion: {in: 0..6}, allow_nil: true
    validates :time_format, inclusion: {in: TIME_FORMATS}, allow_nil: true
    validates :theme, inclusion: {in: THEMES}, allow_nil: true
    # IANA identifiers only: ActiveSupport::TimeZone also accepts aliases like "Rome".
    validates :time_zone, :detected_time_zone, inclusion: {in: ->(_user) { TZInfo::Timezone.all_identifiers }}, allow_nil: true
    validates :day_start_hour, :day_end_hour, numericality: {only_integer: true, in: 0..23}
    validate :day_hours_in_order
  end

  private

  # The last hour shown cannot come before the first. Only checked when both
  # are whole numbers: otherwise the validation above has already said what is
  # wrong.
  def day_hours_in_order
    return unless day_start_hour.is_a?(Integer) && day_end_hour.is_a?(Integer)

    errors.add(:day_end_hour, :before_start) if day_end_hour < day_start_hour
  end
end
