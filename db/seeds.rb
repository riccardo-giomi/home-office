# Demo data only in development, always idempotent (find_or_create_by).
# Later sections add their records below this guard and keep test/seeds_test.rb green.
return unless Rails.env.development?
