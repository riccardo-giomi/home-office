# A link between two entities of one user.
#
# It has no direction and no data. It is stored once, with the lower id first,
# so the pair of ends is unique whichever way round it was made.
#
# The ends are optional associations because the composite foreign keys
# guarantee them, and a presence check would load them (strict loading).
class Core::Link < ApplicationRecord
  belongs_to :user
  belongs_to :first_entity, class_name: "Core::Entity", optional: true
  belongs_to :second_entity, class_name: "Core::Entity", optional: true

  before_validation :put_ends_in_order
  validate :ends_are_two_kept_entities_of_the_user

  scope :involving, ->(ids) { where(first_entity_id: ids).or(where(second_entity_id: ids)) }

  # The link between the two records, made if it is not there yet.
  #
  # `previously_new_record?` on the result tells which. When an end is missing,
  # in the trash, the same as the other or someone else's, the result is not
  # saved and its errors say why; nothing is raised.
  def self.connect(user, a_id, b_id)
    existing(user.id, a_id, b_id) || create(user:, first_entity_id: a_id, second_entity_id: b_id)
  end

  def self.existing(user_id, a_id, b_id)
    first, second = [a_id.to_i, b_id.to_i].sort
    find_by(user_id:, first_entity_id: first, second_entity_id: second)
  end

  def other_id(entity_id) = (first_entity_id == entity_id) ? second_entity_id : first_entity_id

  # Replaces the end opposite `entity_id` with `to_id`.
  #
  # When the new pair is a link already, that link is returned and nothing
  # changes.
  def reconnect(entity_id, to_id)
    found = self.class.existing(user_id, entity_id, to_id)
    return found if found

    self.first_entity_id = entity_id
    self.second_entity_id = to_id.to_i
    save
    self
  end

  private

  def put_ends_in_order
    return unless first_entity_id && second_entity_id

    self.first_entity_id, self.second_entity_id = [first_entity_id, second_entity_id].sort
  end

  # One query for both ends, with no association reads (strict loading).
  def ends_are_two_kept_entities_of_the_user
    return errors.add(:base, :self_link) if first_entity_id && first_entity_id == second_entity_id

    found = Core::Entity.kept.where(id: [first_entity_id, second_entity_id], user_id:).count
    errors.add(:base, :unavailable) unless found == 2
  end
end
