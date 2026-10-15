class Core::UI::FormActionsComponentPreview < ViewComponent::Preview
  # Save at one end, the dangerous action at the other; below sm they stack, stretched. Narrow the frame to see it.
  def with_danger_action
    render(Core::UI::FormActionsComponent.new) do |component|
      component.with_primary { save }
      component.with_danger { delete_modal }
    end
  end

  def only_the_main_action
    render(Core::UI::FormActionsComponent.new) { |component| component.with_primary { save } }
  end

  private

  def save = ApplicationController.helpers.tag.button("Save event", type: "button", class: "btn btn-primary")

  def delete_modal
    modal = Core::UI::ModalComponent.new(id: "delete-demo", title: "Delete this event?", trigger: "Delete event", trigger_variant: :danger)
    ApplicationController.render(modal.with_content("It will be deleted for good."), layout: false).html_safe
  end
end
