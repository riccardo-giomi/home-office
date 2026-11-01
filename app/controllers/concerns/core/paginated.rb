# Pages a relation in a controller action.
module Core::Paginated
  extend ActiveSupport::Concern
  include Pagy::Method

  PER_PAGE = 25

  private

  # Returns the Pagy object and the records of the requested page.
  #
  # If the page number is past the last page (records were deleted or moved since
  # the address was saved), it redirects to the last page and returns nil.
  #
  # The action must then stop with `return if performed?`.
  #
  # `url_options` are the parameters of the address, besides `page`, that the
  # redirect keeps: the ones in the query string, such as `type:`.
  #
  # The path parameters of the current action are always kept.
  def paginate(relation, limit: PER_PAGE, **url_options)
    pagy, records = pagy(:offset, relation, limit:)
    return [pagy, records] unless records.empty? && pagy.page > pagy.last

    redirect_to url_for(url_options.merge(page: pagy.last))
    nil
  end
end
