module Core::ThemeHelper
  def theme_attributes
    effective_preferences.theme ? {"data-theme" => effective_preferences.theme} : {}
  end

  # One preview example, rendered inside the page (a fresh component instance on every call)
  def render_preview_example(preview, example)
    args = preview.render_args(example)
    render(args[:component], args[:args], &args[:block])
  end
end
