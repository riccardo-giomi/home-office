class Core::UI::StatCardComponentPreview < ViewComponent::Preview
  def default
    render(Core::UI::StatCardComponent.new(title: "Events", href: "#", lines: [{label: "This week", count: 7, href: "#"}, {label: "Today", count: 2, href: "#"}, {label: "Important", count: 3, href: "#"}, {label: "Missed events", count: 12, href: "#"}]))
  end

  def with_total
    render(Core::UI::StatCardComponent.new(title: "Todos", href: "#", total: "5 to do", lines: [{label: "Urgent", count: 1, href: "#"}]))
  end

  def all_zeros
    render(Core::UI::StatCardComponent.new(title: "Tasks", href: "#", lines: [{label: "Today", count: 0, href: "#"}, {label: "This week", count: 0, href: "#"}, {label: "Forgotten", count: 0, href: "#"}]))
  end

  def long_labels
    render(Core::UI::StatCardComponent.new(title: "A card with a very long title that goes on", href: "#", total: "1234567 in all", lines: [{label: "Supercalifragilisticexpialidocious" * 3, count: 1234567, href: "#"}]))
  end

  # Below 640 px the narrow links show and from 640 px the other links show;
  # resize the frame to see them swap
  def with_narrow_links
    render(Core::UI::StatCardComponent.new(title: "Events", href: "#wide", narrow_href: "#narrow", lines: [{label: "This week", count: 4, href: "#wide-week", narrow_href: "#narrow-week"}, {label: "Today", count: 1, href: "#today"}]))
  end
end
