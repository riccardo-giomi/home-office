# The records of one kind a person can pick to link, found by a part of the
# title.
#
# It returns ten at most and says when there were more, so the person narrows
# the search instead of paging.
class Core::LinkCandidates
  LIMIT = 10

  def initialize(user:, kind:, term:, except_id: nil)
    @user = user
    @kind = kind
    @term = term.to_s.strip
    @except_id = except_id
  end

  def results = found.first(LIMIT)

  def more? = found.size > LIMIT

  private

  def found
    @found ||= begin
      scope = @kind.scope.call(@user)
      scope = scope.where.not(id: @except_id) if @except_id
      scope = Core::TitleMatch.apply(scope, @term)
      scope.order(:title, :id).limit(LIMIT + 1).to_a
    end
  end
end
