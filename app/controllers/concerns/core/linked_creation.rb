# For a controller that creates records: "New linked" opens the normal new form
# with `linked_to`, the new record will be linked to what the parameter specifies.
#
# The source is looked up through the current user and must be kept; anything
# else is a 404.
module Core::LinkedCreation
  extend ActiveSupport::Concern

  included do
    helper_method :linked_source
  end

  private

  def linked_source
    return if params[:linked_to].blank?

    @linked_source ||= Core::Entity.kept.where(user_id: Current.user.id).includes(:record).find(params[:linked_to])
  end

  # What a new record takes from its source.
  def linked_attributes = linked_source ? {title: linked_source.record.for_links.label} : {}

  # Saves the record and its link in one transaction: both, or neither.
  #
  # When the link is refused, its reasons are copied onto the record so the form
  # says why nothing was saved.
  def save_and_link(record)
    return record.save unless linked_source

    saved = false
    Core::Link.transaction do
      next unless record.save

      link = Core::Link.connect(Current.user, record.id, linked_source.id)
      saved = link.persisted?
      link.errors.full_messages.each { |message| record.errors.add(:base, message) } unless saved
      raise ActiveRecord::Rollback unless saved
    end
    saved
  end
end
