require "test_helper"

class Core::ErrorLogSubscriberTest < ActiveSupport::TestCase
  let(:output) { StringIO.new }
  let(:error) { RuntimeError.new("boom") }

  def logged
    original = Rails.logger
    Rails.logger = ActiveSupport::Logger.new(output).tap do |logger|
      logger.formatter = ->(severity, _time, _program, message) { "#{severity}: #{message}\n" }
    end
    yield
    output.string
  ensure
    Rails.logger = original
  end

  it "logs the error with its class, message, state and source" do
    text = logged do
      Core::ErrorLogSubscriber.new.report(error, handled: true, severity: :warning, context: {}, source: "application")
    end
    _(text).must_include "RuntimeError: boom (handled, source: application, context: {})"
  end

  it "logs an unhandled error at the error level" do
    text = logged do
      Core::ErrorLogSubscriber.new.report(error, handled: false, severity: :error, context: {user_id: 7}, source: "application")
    end
    _(text).must_include "ERROR: RuntimeError: boom (unhandled, source: application, context: {user_id: 7})"
  end

  it "logs a warning at the warn level" do
    text = logged do
      Core::ErrorLogSubscriber.new.report(error, handled: true, severity: :warning, context: {}, source: "application")
    end
    _(text).must_match(/\AWARN: RuntimeError: boom/)
  end

  it "is subscribed to Rails.error, so a reported error reaches the log" do
    text = logged { Rails.error.report(RuntimeError.new("reported"), handled: true) }
    _(text).must_include "RuntimeError: reported (handled, source: application"
  end
end
