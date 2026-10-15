class Core::UI::ModalComponentPreview < ViewComponent::Preview
  def default
    render(Core::UI::ModalComponent.new(id: "modal-default", title: "Delete this item?", trigger: "Delete")) do
      "It moves to the trash and can be restored for 30 days."
    end
  end

  def long_content
    render(Core::UI::ModalComponent.new(id: "modal-long", title: "A long explanation", trigger: "Read more")) do
      tag.div do
        safe_join(Array.new(12) { |i| tag.p("Paragraph #{i + 1}. The dialog scrolls inside its box on a small screen.", class: "mb-2") } + [tag.a("A link inside", href: "/", class: "link inline-flex items-center min-h-6")])
      end
    end
  end
end
