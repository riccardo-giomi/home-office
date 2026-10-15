require "io/console"

# Ordered, re-runnable install steps.
class Core::Setup::Runner
  def self.default_steps = [Core::Setup::AdminStep.new]

  def initialize(steps: self.class.default_steps, input: $stdin, output: $stdout, env: ENV,
    password_reader: ->(prompt) { IO.console&.getpass(prompt) })
    @steps = steps
    @input = input
    @output = output
    @env = env
    @password_reader = password_reader
  end

  def call(email: nil)
    context = Core::Setup::Context.new(email:, input: @input, output: @output, env: @env, password_reader: @password_reader)
    @steps.each do |step|
      @output.puts I18n.t("core.setup.running", title: step.title)
      @output.puts "  #{step.call(context)}"
    end
  end
end
