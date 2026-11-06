require "test_helper"

# public/*.html are served by the web server, or by Rails when nothing else answers: they cannot use the asset pipeline
# or I18n, so they carry one shared block of CSS. These checks keep the five from drifting apart.
describe "the static error pages" do
  pages = %w[400.html 404.html 406-unsupported-browser.html 422.html 500.html]

  def html(page) = Rails.root.join("public", page).read

  def style(page) = html(page)[%r{<style>(.*?)</style>}m, 1]

  def luminance(hex)
    hex.delete("#").scan(/../).map { |pair| pair.hex / 255.0 }.map { |c| (c <= 0.03928) ? c / 12.92 : ((c + 0.055) / 1.055)**2.4 }
      .then { |r, g, b| 0.2126 * r + 0.7152 * g + 0.0722 * b }
  end

  def contrast(one, other)
    light, dark = [luminance(one), luminance(other)].sort.reverse
    (light + 0.05) / (dark + 0.05)
  end

  pages.each do |page|
    describe page do
      it "is a small English page with a title, one heading and a way back" do
        _(html(page)).must_match(/<html lang="en">/)
        _(html(page)[%r{<title>(.*?)</title>}, 1]).must_match(/\A[A-Z][^.]* \| Home Office\z/)
        _(html(page)).must_match(/name="viewport"/)
        _(html(page).scan("<h1>").size).must_equal 1
        _(html(page)).must_include '<a href="/">'
      end

      it "has no script and asks nothing of any other server" do
        _(html(page)).wont_match(/<script/i)
        _(html(page)).wont_match(%r{https?://})
        _(html(page)).wont_match(/@import|url\(/)
      end

      it "shares its style with the others" do
        _(style(page)).must_equal style(pages.first)
      end
    end
  end

  it "keeps text and links readable in both colour schemes" do
    css = style(pages.first)
    light = css[/:root\s*\{(.*?)\}/m, 1]
    dark = css[/prefers-color-scheme:\s*dark\)\s*\{\s*:root\s*\{(.*?)\}/m, 1]
    _(dark).wont_be_nil
    {"light" => light, "dark" => dark}.each do |name, block|
      colour = ->(property) { block[/--#{property}:\s*(#\h{6})/, 1] }
      _(contrast(colour.call("text"), colour.call("page"))).must_be :>=, 4.5, "#{name} text"
      _(contrast(colour.call("link"), colour.call("page"))).must_be :>=, 4.5, "#{name} link"
    end
  end
end
