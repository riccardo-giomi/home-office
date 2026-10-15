# Demo data only in development, always idempotent (find_or_create_by).
return unless Rails.env.development?

{"demo-admin@example.com" => :admin, "demo-user@example.com" => :user}.each do |email, role|
  User.find_or_create_by!(email_address: email) { |user| user.assign_attributes(role:, password: "development-only-password") }
end
