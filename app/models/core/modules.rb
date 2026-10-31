module Core::Modules
  @manifests = []

  class << self
    def register(manifest)
      return manifest if @manifests.any? { |known| known.name == manifest.name }

      clash = manifest.linkable_kinds.map(&:key) & linkable_kinds.map(&:key)
      raise ArgumentError, "linkable kind keys already taken: #{clash.join(", ")}" if clash.any?

      @manifests << manifest
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

    def linkable_kinds = all.flat_map(&:linkable_kinds)

    # A hash lookup: a key from a request is never turned into a class.
    def linkable_kind(key) = linkable_kinds.find { |kind| kind.key == key }

    def trash_sources = all.filter_map(&:trash)

    # What a module keeps in the trash besides the entities goes first: it may
    # need the entities it takes along.
    def purge_expired(now = Time.current) = all.filter_map(&:purge).each { |hook| hook.call(now) }

    # Calls the `catch_up` hook of every module for the user. An error raised by
    # a hook is reported with `Rails.error.report` and does not stop the
    # request.
    def catch_up(user, today:)
      all.filter_map(&:catch_up).each do |hook|
        hook.call(user, today)
      rescue => error
        Rails.error.report(error, handled: true)
      end
    end

    def trash_total(user) = trash_sources.sum { |source| source.total.call(user) }
  end
end
