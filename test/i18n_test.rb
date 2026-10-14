require "test_helper"
require "i18n/tasks"

describe "I18n" do
  let(:i18n) { I18n::Tasks::BaseTask.new }

  it "has no missing keys" do
    _(i18n.missing_keys.leaves.map(&:full_key)).must_be_empty
  end

  it "has no unused keys" do
    _(i18n.unused_keys.leaves.map(&:full_key)).must_be_empty
  end

  it "has normalized locale files" do
    _(i18n.non_normalized_paths).must_be_empty
  end

  it "loads only en and it" do
    _(I18n.available_locales).must_equal %i[en it]
  end

  it "keeps every locale file at config/locales/<module>/<locale>.yml" do
    strays = Dir[Rails.root.join("config/locales/**/*.yml")].reject do |path|
      path.match?(%r{config/locales/[a-z_]+/(en|it)\.yml\z})
    end
    _(strays).must_be_empty
  end

  it "raises on a missing translation in a view" do
    error = _ { ApplicationController.render(inline: "<%= t('nope.never') %>") }.must_raise ActionView::Template::Error
    _(error.message).must_match(/Translation missing/)
  end
end
