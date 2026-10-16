class Core::UI::CheckboxComponentPreview < ViewComponent::Preview
  def unchecked
    render(Core::UI::CheckboxComponent.new(name: "done", checked: false, label: "Done: Pay the rent", id: "checkbox-unchecked"))
  end

  def checked
    render(Core::UI::CheckboxComponent.new(name: "done", checked: true, label: "Done: Pay the gas bill", id: "checkbox-checked"))
  end
end
