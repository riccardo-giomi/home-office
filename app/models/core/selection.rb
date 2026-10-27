# Up to two records the user has set aside, to link them or to link another
# record to one of them.
#
# It is kept in session: nothing to store, and it lasts as long as the
# browser session cookie. If something "disappears" (it's trashed or purged),
# it is dropped whenever it is read.
class Core::Selection
  LIMIT = 2
  KEY = :selected_entity_ids

  def initialize(session, user)
    @session = session
    @user = user
  end

  def ids = Array(@session[KEY]).filter_map { |id| Integer(id, exception: false) }.uniq.first(LIMIT)

  def include?(id) = ids.include?(id.to_i)

  def full? = ids.size >= LIMIT

  # False when two are selected already.
  def add(id)
    return true if include?(id)
    return false if full?

    save(ids + [id.to_i])
    true
  end

  def remove(id) = save(ids - [id.to_i])

  def clear = save([])

  # The entities with their records, in the order chosen: the user's own and
  # not in the trash. One query, none when nothing is selected.
  def entries
    @entries ||= begin
      chosen = ids
      found = chosen.empty? ? {} : Core::Entity.kept.where(user_id: @user.id, id: chosen).includes(:record).select(&:record).index_by(&:id)
      save(chosen & found.keys) if found.size != chosen.size
      found.values_at(*chosen).compact
    end
  end

  private

  def save(ids)
    @entries = nil
    @session[KEY] = ids
  end
end
