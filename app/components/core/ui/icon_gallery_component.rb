# Every icon next to the others, at its normal size and larger: the way to check that they belong
# together. It lists IconComponent::PATHS, so a new icon appears here without touching the preview.
class Core::UI::IconGalleryComponent < ApplicationComponent
  def call
    tag.ul(class: "grid grid-cols-[repeat(auto-fill,minmax(7rem,1fr))] gap-3") do
      safe_join(Core::UI::IconComponent::PATHS.keys.map { |name| cell(name) })
    end
  end

  private

  def cell(name)
    tag.li(class: "flex flex-col items-center gap-2 rounded-box border border-base-300 bg-base-100 p-3") do
      safe_join([
        tag.span(class: "flex items-end gap-3") do
          safe_join([render(Core::UI::IconComponent.new(name:)), render(Core::UI::IconComponent.new(name:, class: "size-10 shrink-0"))])
        end,
        tag.code(name, class: "text-sm break-all text-center")
      ])
    end
  end
end
