module Core::Modules
  @manifests = []

  class << self
    def register(manifest)
      @manifests << manifest unless @manifests.any? { |known| known.name == manifest.name }
      manifest
    end

    def reset! = @manifests.clear

    def all = @manifests.dup

    # Admin entries come after every module's own, whichever module registered them
    def navigation(admin:, placement: :main)
      items = all.flat_map(&:navigation).select { |item| item.placement == placement && (admin || !item.admin) }
      items.partition { |item| !item.admin }.flatten(1)
    end

    def setup_steps = all.flat_map(&:setup_steps)

    def trash_sources = all.filter_map(&:trash)

    def trash_total(user) = trash_sources.sum { |source| source.total.call(user) }
  end
end
