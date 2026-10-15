# The buttons at the end of a form: the main action at one end of the line, the dangerous one at the
# other, so one cannot be hit by mistake for the other. On a phone they stack, stretched, with room between.
# The primary button is outside the <form> element when the dangerous one is a separate form (a modal):
# give it `form: "<form id>"`.
class Core::UI::FormActionsComponent < ApplicationComponent
  renders_one :primary
  renders_one :danger

  CLASSES = "mt-8 flex flex-col gap-8 sm:flex-row sm:items-center sm:justify-between " \
    "[&>.btn]:w-full [&>div>.btn]:w-full sm:[&>.btn]:w-auto sm:[&>div>.btn]:w-auto".freeze

  def call
    tag.div(safe_join([primary, danger].compact), class: CLASSES)
  end
end
