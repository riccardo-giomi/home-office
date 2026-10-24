module Core::TrashHelper
  # The lines of a module's card.
  #
  # How many of each kind are in its trash, zeros included.
  def trash_card_lines(source)
    source.counts.call(Current.user).map { |kind, count| t("#{source.labels_key}.#{kind}", count:) }
  end
end
