# Index action for a page that lists items grouped by day, 25 items per page,
# oldest day first.
#
# The including controller defines two private methods:
#
# - `items`: the relation of the items to list.
# - `back_path`: the path that the Back link of the page goes to.
#
# The texts of the page are under `planner.<controller name>.index`.
module Planner::PagedAgendaList
  extend ActiveSupport::Concern
  include Core::Paginated

  included do
    # defined in the including controller.
    helper_method :back_path
  end

  def index
    @pagy, page_items = paginate(items.order(:day, :starts_at, :id))
    return if performed?

    @kind = controller_name
    @items_by_day = page_items.group_by(&:day)
    @link_index = Core::LinkIndex.new(page_items.map(&:id))
    render "planner/paged_agenda_lists/index"
  end
end
