# Words and rows of the trash page.
module Planner::TrashHelper
  # The tabs of the trash page: all, then each kind.
  #
  # Each is [label, address, current?], with how many are in it.
  def trash_tabs(trash)
    all = [t("planner.trashes.show.all", count: trash.total), planner_trash_path, trash.type.nil?]
    kinds = Planner::Trash::KINDS.map do |kind|
      label = "#{t("planner.trash.kinds.#{kind}", count: 2)} (#{trash.counts.fetch(kind)})"
      [label, planner_trash_path(type: kind), trash.type == kind]
    end
    [all, *kinds]
  end

  # A trashed series is one row, however many parts and events it holds.
  def trashed_series_row(group, type:)
    {
      id: "trashed_series_#{group.id}",
      detail: safe_join([
        t("planner.trash.kinds.series", count: 1),
        t("planner.trashes.show.trashed_on_html", date: format_date(group.deleted_at.in_time_zone.to_date))
      ], " · "),
      actions: restore_series_button(group, type:)
    }
  end

  # "Series: Gym (every 2 weeks on Mon)"
  def trashed_series_title(group)
    t("planner.trashes.show.series_title", title: group.first.title, rule: group.first.rule.summary.downcase_first)
  end

  def restore_series_button(group, type:)
    form_with(url: planner_series_restoration_path(group.id), method: :patch) do
      safe_join([
        (hidden_field_tag(:type, type, id: nil) if type),
        render(Core::UI::ButtonComponent.new(type: :submit, variant: :secondary, size: :sm)) do
          safe_join([t("planner.trashes.show.restore"), tag.span(" #{group.first.title}", class: "sr-only")])
        end
      ].compact)
    end
  end

  def trashed_row(item, type:)
    {id: "trashed_#{item.id}", detail: trashed_detail(item), actions: restore_button(item, type:)}
  end

  # The detail line of a trashed row.
  #
  # Kind, the item's own day and times when it has them (to tell look-alikes
  # apart), and when it was trashed.
  def trashed_detail(item)
    parts = [t("planner.trash.kinds.#{item.class.kind}", count: 1)]
    parts << trashed_moment(item) if item.timed? && item.day
    parts << t("planner.trashes.show.trashed_on_html", date: format_date(item.deleted_at.in_time_zone.to_date))
    safe_join(parts, " · ")
  end

  def restore_button(item, type:)
    form_with(url: planner_item_restoration_path(item), method: :patch) do
      safe_join([
        (hidden_field_tag(:type, type, id: nil) if type),
        render(Core::UI::ButtonComponent.new(type: :submit, variant: :secondary, size: :sm)) do
          safe_join([t("planner.trashes.show.restore"), tag.span(" #{item.title}", class: "sr-only")])
        end
      ].compact)
    end
  end

  private

  def trashed_moment(item)
    times = if item.starts_at
      safe_join([format_time(item.starts_at, zone: item.time_zone), "–", format_time(item.ends_at, zone: item.time_zone)])
    else
      t("core.ui.entry.all_day")
    end
    tag.span(safe_join([format_date(item.day), times], " "), class: "whitespace-nowrap")
  end
end
