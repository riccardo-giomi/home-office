module Core::ThemeHelper
  # One preview example, rendered inside the page (a fresh component instance on every call)
  def render_preview_example(preview, example)
    args = preview.render_args(example)
    render(args[:component], args[:args], &args[:block])
  end
end
