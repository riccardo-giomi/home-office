# Making, changing and removing links between two of the user's records, and
# the picker that finds the other end.
#
# Every id is looked up through the current user: someone else's record or link
# is a 404.
class LinksController < ApplicationController
  before_action :set_entity
  before_action :set_link, only: %i[update destroy]

  # The picker, drawn inside the frame the record's page holds: a kind at a
  # time, searched by title.
  def new
    @kind = Core::Modules.linkable_kind(params[:kind]) || Core::Modules.linkable_kinds.first
    @change = find_link(params[:change]) if params[:change].present?
    @term = params[:q].to_s
    @candidates = Core::LinkCandidates.new(user: Current.user, kind: @kind, term: @term, except_id: @entity.id)
    @linked_ids = Core::LinkIndex.new(@entity.id).ends_of(@entity.id).map { |link_end| link_end.entity.id }
  end

  def create
    other = find_entity(params[:other_id])
    link = Core::Link.connect(Current.user, @entity.id, other.id)
    if !link.persisted?
      answer :alert, link.errors.full_messages.to_sentence
    elsif link.previously_new_record?
      answer :notice, t(".created", title: other.record.for_links.label)
    else
      answer :notice, t("links.already", title: other.record.for_links.label)
    end
  end

  # Replaces the other end of a link, seen from this record.
  def update
    other = find_entity(params[:other_id])
    link = @link.reconnect(@entity.id, other.id)
    if link.errors.any?
      answer :alert, link.errors.full_messages.to_sentence
    elsif link.id == @link.id
      answer :notice, t(".changed", title: other.record.for_links.label)
    else
      answer :notice, t("links.already", title: other.record.for_links.label)
    end
  end

  # At once: no confirmation, and no trash for a link.
  def destroy
    title = other_end_label(@link)
    @link.destroy!
    answer :notice, t(".removed", title:)
  end

  private

  def set_entity = @entity = find_entity(params[:entity_id])

  def find_entity(id) = Core::Entity.kept.where(user_id: Current.user.id).includes(:record).find(id)

  def find_link(id)
    link = Core::Link.where(user_id: Current.user.id).find(id)
    raise ActiveRecord::RecordNotFound unless [link.first_entity_id, link.second_entity_id].include?(@entity.id)

    link
  end

  def set_link = @link = find_link(params[:id])

  # The other end may be in the trash, so its entity is read without the kept
  # filter.
  def other_end_label(link)
    Core::Entity.where(user_id: Current.user.id).includes(:record).find(link.other_id(@entity.id)).record.for_links.label
  end

  # Says what has been done, and shows it where the user is.
  #
  # A request from the Links section (`in_section`) gets the section drawn again
  # with the message as a status, and focus on its heading. The dialog hides the
  # page's own notice, which is why the section carries one. The page behind
  # refreshes either way, so its summaries and bar are up to date.
  #
  # Other requests, such as the bar that links the two selected records, are
  # not on the page of either: drawing a section there would put one record's
  # section on another's page.
  def answer(kind, message)
    flash[kind] = message
    current_selection.clear if params[:clear_selection].present? && kind == :notice
    respond_to do |format|
      format.turbo_stream do
        streams = []
        if params[:in_section].present?
          streams << turbo_stream.replace("links-section", helpers.links_section(@entity.id, notice: message))
          streams << turbo_stream.action(:focus, "links-section-heading")
        end
        render turbo_stream: streams << turbo_stream.refresh(request_id: nil)
      end
      format.html { redirect_back_or_to polymorphic_path(@entity.record), status: :see_other }
    end
  end
end
