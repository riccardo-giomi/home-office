class Core::UI::DateFieldComponentPreview < ViewComponent::Preview
  # The weekday and the date in the user's format, above the browser's own field
  def with_date
    render_field(ExampleUser.new(day: Date.new(2026, 12, 1)))
  end

  def empty
    render_field(ExampleUser.new)
  end

  def with_hint
    render_field(ExampleUser.new(day: Date.new(2026, 12, 1)), hint: "The first day of the series")
  end

  private

  # A throwaway form builder: previews have no surrounding form, and the namespace keeps ids unique when
  # several examples share one page
  def render_field(record, **options)
    form = ActionView::Helpers::FormBuilder.new(record.model_name.param_key, record, ActionView::Base.empty, {namespace: SecureRandom.hex(3)})
    render Core::UI::DateFieldComponent.new(form:, attribute: :day, label: "Day", **options)
  end
end
