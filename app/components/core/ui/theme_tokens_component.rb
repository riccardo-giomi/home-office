# Every color pair of the theme, labeled with its token name
class Core::UI::ThemeTokensComponent < ApplicationComponent
  # Written out in full: Tailwind only emits classes it finds in the source
  TOKENS = {
    "base-100" => "bg-base-100 text-base-content",
    "base-200" => "bg-base-200 text-base-content",
    "base-300" => "bg-base-300 text-base-content",
    "primary" => "bg-primary text-primary-content",
    "secondary" => "bg-secondary text-secondary-content",
    "accent" => "bg-accent text-accent-content",
    "neutral" => "bg-neutral text-neutral-content",
    "info" => "bg-info text-info-content",
    "success" => "bg-success text-success-content",
    "warning" => "bg-warning text-warning-content",
    "error" => "bg-error text-error-content"
  }.freeze
end
