require "test_helper"

describe Core::AcceptLanguage do
  def match(header, available: %i[en it])
    Core::AcceptLanguage.best_match(header, available:)
  end

  it "picks the supported language with the highest quality" do
    _(match("it-IT,it;q=0.9,en;q=0.8")).must_equal :it
    _(match("en;q=0.5, it;q=0.9")).must_equal :it
    _(match("it;q=0.4, en")).must_equal :en
  end

  it "reads the language and ignores region and case" do
    _(match("IT-ch")).must_equal :it
    _(match("en-GB")).must_equal :en
  end

  it "skips unsupported languages" do
    _(match("fr-FR,de;q=0.8,it;q=0.5")).must_equal :it
    _(match("fr, de")).must_be_nil
  end

  it "ignores q=0, wildcards and malformed entries" do
    _(match("it;q=0, en;q=0.1")).must_equal :en
    _(match("*")).must_be_nil
    _(match(";;;,,q=")).must_be_nil
  end

  it "reads a good entry after junk and survives text that is not valid" do
    _(match(";;;,it")).must_equal :it
    _(match("it;q=0.9,\xFF\xFE,en;q=0.1".b.force_encoding("UTF-8"))).must_equal :it
  end

  it "copes with a missing, empty or enormous header" do
    _(match(nil)).must_be_nil
    _(match("")).must_be_nil
    _(match("x" * 10_000)).must_be_nil
    _(match(("fr," * 5000) + "it")).must_be_nil
  end
end
