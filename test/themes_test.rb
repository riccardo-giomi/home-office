require "test_helper"

# The stylesheet is built by Tailwind from app/assets/tailwind; this checks what the browser will get
describe "themes" do
  let(:css) { File.read(Rails.root.join("app/assets/builds/tailwind.css")) }

  it "defines a light and a dark theme" do
    _(css).must_match(/\[data-theme=light\]/)
    _(css).must_match(/\[data-theme=dark\]/)
  end

  it "follows the browser's color scheme when no theme is chosen" do
    _(css).must_match(/:root:not\(\[data-theme\]\)/)
    _(css).must_match(/prefers-color-scheme:\s*dark/)
  end

  it "uses Inter, served from the app" do
    _(css).must_include "Inter"
    _(File).must_be :exist?, Rails.root.join("app/assets/fonts/InterVariable.woff2")
    _(File).must_be :exist?, Rails.root.join("app/assets/fonts/Inter-LICENSE.txt")
  end
end
