require "test_helper"

# Raw palette colors bypass the themes (and dark mode); colors come from daisyUI tokens
describe "colors" do
  it "uses theme tokens, never Tailwind palette colors, in app code" do
    palette = /\b(?:text|bg|border|ring|fill|stroke|from|to|via)-(?:red|green|blue|gray|slate|zinc|neutral|stone|orange|amber|yellow|lime|emerald|teal|cyan|sky|indigo|violet|purple|fuchsia|pink|rose)-\d{2,3}\b/
    offenders = Dir[Rails.root.join("app/{views,components,helpers}/**/*.{erb,rb}")].select { |file| File.read(file).match?(palette) }
    _(offenders.map { |file| Pathname(file).relative_path_from(Rails.root).to_s }).must_be_empty
  end
end
