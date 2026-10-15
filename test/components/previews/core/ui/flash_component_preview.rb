class Core::UI::FlashComponentPreview < ViewComponent::Preview
  def notice
    render Core::UI::FlashComponent.new(kind: "notice", message: "Saved")
  end

  def alert
    render Core::UI::FlashComponent.new(kind: "alert", message: "Something went wrong")
  end
end
