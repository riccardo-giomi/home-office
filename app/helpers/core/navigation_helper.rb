module Core::NavigationHelper
  # Manifest order, consecutive items of one group joined under its title
  def navigation_groups
    return [] unless Current.user

    Core::Modules.navigation(admin: Current.user.admin?).chunk_while do |a, b|
      a.group_key == b.group_key
    end.map do |chunk|
      label = chunk.first.group_key && t(chunk.first.group_key)
      items = chunk.map { |item| sidebar_item(item) }
      Core::UI::SidebarComponent::Group.new(label, items)
    end
  end

  # Links kept beside the account box at the bottom of the sidebar
  def navigation_footer_items
    return [] unless Current.user

    Core::Modules
      .navigation(admin: Current.user.admin?, placement: :footer)
      .map { |item| sidebar_item(item) }
  end

  private

  def sidebar_item(item)
    Core::UI::SidebarComponent::Item.new(t(item.label_key), public_send(item.route), item.icon)
  end
end
