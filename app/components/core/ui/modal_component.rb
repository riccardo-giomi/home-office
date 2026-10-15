# A native <dialog>: the browser provides the focus trap, Escape and focus return to the trigger
class Core::UI::ModalComponent < ApplicationComponent
  def initialize(id:, title:, trigger:, trigger_variant: :secondary, trigger_size: nil)
    @id = id
    @title = title
    @trigger = trigger
    @trigger_variant = trigger_variant
    @trigger_size = trigger_size
  end
end
