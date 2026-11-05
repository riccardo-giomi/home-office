# Searches in entity titles.
#
# The one place that escapes LIKE for a title search. The link picker and the
# list of the MCP tools use it.
module Core::TitleMatch
  # Returns the scope with only the records whose title holds the term.
  #
  # A blank term returns the scope as it is. `%`, `_` and `\` are taken as the
  # letters they are, not as wildcards.
  def self.apply(scope, term)
    term = term.to_s.strip
    return scope if term.empty?

    scope.where(scope.arel_table[:title].matches("%#{escaped(term)}%", "\\"))
  end

  def self.escaped(term) = term.gsub(/[\\%_]/) { |char| "\\#{char}" }
  private_class_method :escaped
end
