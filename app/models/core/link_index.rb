# The links of a set of entities, read at once.
#
# The links, the entities at their ends and those entities' records are three
# queries however many links there are. A page asks for the ids it shows, then
# reads the ends of each.
class Core::LinkIndex
  # The other end of a link, as seen from one entity.
  End = Data.define(:link, :entity, :record) do
    def trashed? = entity.trashed?

    def facts = record.for_links

    def kind_key = facts.kind

    def label = facts.label

    def status = facts.status

    def day = facts.day

    # [label, address] of the page that holds the record, when its kind says
    # where it lives.
    def home = Core::LinkableKind.home_of(record)
  end

  def initialize(entity_ids)
    @ends = Hash.new { |hash, id| hash[id] = [] }
    ids = Array(entity_ids)
    return if ids.empty?

    Core::Link.involving(ids).includes(first_entity: :record, second_entity: :record).order(:created_at, :id).each do |link|
      add(link, link.first_entity, link.second_entity) if ids.include?(link.first_entity_id)
      add(link, link.second_entity, link.first_entity) if ids.include?(link.second_entity_id)
    end
    # sort_by! without a block returns an enumerator; with_index adds each
    # end's position as a tie-breaker.
    @ends.each_value { |ends| ends.sort_by!.with_index { |link_end, position| [link_end.trashed? ? 1 : 0, position] } }
  end

  # Kept ends first, then those in the trash, each group oldest link first.
  def ends_of(entity_id) = @ends.fetch(entity_id, [])

  def kept_count(entity_id) = ends_of(entity_id).count { |link_end| !link_end.trashed? }

  private

  def add(link, own, other)
    @ends[own.id] << End.new(link:, entity: other, record: other.record)
  end
end
