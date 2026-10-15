class Admin::ThemesController < Admin::BaseController
  def show
    # Components that exist once per page (header, sidebar...) cannot be repeated inside one
    @previews = ViewComponent::Preview.all.reject { |preview| preview.try(:page_level?) }.sort_by(&:name)
  end
end
