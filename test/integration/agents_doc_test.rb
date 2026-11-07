require "test_helper"

# README.md and AGENTS.md each stand alone: a person may read only the first,
# an agent only the second. Both must name every HOME_OFFICE_ setting that the
# application has, and AGENTS.md every MCP tool, each in backticks.
def documented_text(name)
  file = Rails.root.join(name)
  file.exist? ? file.read : ""
end

# The files are read as binary: fonts and images live in the same directories.
def undocumented_settings(text)
  files = Dir[Rails.root.join("{app,config,lib,bin}/**/*")].select { |file| File.file?(file) }
  files << Rails.root.join("Dockerfile").to_s
  used = files.flat_map { |file| File.binread(file).scan(/HOME_OFFICE_[A-Z_]+/n) }.uniq
  raise "no HOME_OFFICE_ variable found" if used.empty?

  used.reject { |name| text.include?("`#{name}`") }
end

describe "AGENTS.md" do
  text = documented_text("AGENTS.md")

  it "exists" do
    assert Rails.root.join("AGENTS.md").exist?
  end

  it "names every MCP tool" do
    missing = Core::Modules.mcp_tools.map(&:tool_name).reject { |name| text.include?("`#{name}`") }
    _(missing).must_be_empty
  end

  it "names every HOME_OFFICE_ variable that the application reads" do
    _(undocumented_settings(text)).must_be_empty
  end
end

describe "README.md" do
  it "names every HOME_OFFICE_ variable that the application reads" do
    _(undocumented_settings(documented_text("README.md"))).must_be_empty
  end
end

describe "the files for people" do
  it "has a MIT license" do
    _(Rails.root.join("LICENSE").read).must_match(/\AMIT License/)
  end

  it "has a README that is not the generated one" do
    _(Rails.root.join("README.md").read).wont_include "This README would normally document"
  end
end
