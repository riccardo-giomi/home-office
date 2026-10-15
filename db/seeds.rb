# Demo data only in development, always idempotent (find_or_create_by).
return unless Rails.env.development?
