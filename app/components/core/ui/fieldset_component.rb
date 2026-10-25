# A titled set of related fields. It is a native fieldset, so assistive
# technology announces the legend with each field inside it.
#
# The hint describes the whole group; give the group an id to link it.
class Core::UI::FieldsetComponent < ApplicationComponent
  def initialize(legend:, hint: nil, id: nil)
    @legend = legend
    @hint = hint
    @id = id
  end

  def call
    tag.fieldset(class: "mb-6", id: @id, "aria-describedby": (hint_id if @hint)) do
      safe_join([
        tag.legend(@legend, class: "mb-2 text-lg font-semibold"),
        (tag.p(@hint, id: hint_id, class: "mb-2 text-sm text-base-content/80") if @hint),
        content
      ].compact)
    end
  end

  private

  def hint_id = "#{@id || "fieldset"}_hint"
end
