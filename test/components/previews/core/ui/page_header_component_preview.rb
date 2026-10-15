class Core::UI::PageHeaderComponentPreview < ViewComponent::Preview
  # One per page: the Theme page leaves it out
  def self.page_level? = true

  def with_back_link
    render(Core::UI::PageHeaderComponent.new(title: "Edit event: Dentist", back_href: "#", back_label: "Back to event"))
  end

  def without_back_link
    render(Core::UI::PageHeaderComponent.new(title: "New event"))
  end

  def long_title
    render(Core::UI::PageHeaderComponent.new(title: "Edit event: #{"A" * 120}", back_href: "#", back_label: "Back to calendar"))
  end
end
