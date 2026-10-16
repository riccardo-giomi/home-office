class Core::AcceptLanguage
  MAX_HEADER_LENGTH = 500

  # "it-IT,it;q=0.9,en;q=0.8" with available [:en, :it] gives :it; nil when nothing matches
  def self.best_match(header, available:)
    new(header).languages.find { |language| available.include?(language) }
  end

  def initialize(header)
    # scrub: a header that is not valid text must not raise in the regexps below
    @header = header.to_s.scrub("").slice(0, MAX_HEADER_LENGTH)
  end

  # Language codes without region, best quality first; q=0, "*" and junk are dropped
  def languages
    entries = @header.split(",").each_with_index.filter_map do |part, index|
      tag, *params = part.strip.split(";").map(&:strip)
      language = tag.to_s.downcase[/\A[a-z]{2,3}/]
      next unless language

      quality = params.filter_map { |param| param[/\Aq=(\d(?:\.\d{0,3})?)\z/i, 1]&.to_f }.first || 1.0
      next if quality.zero?

      [-quality, index, language.to_sym]
    end
    entries.sort.map(&:last).uniq
  end
end
