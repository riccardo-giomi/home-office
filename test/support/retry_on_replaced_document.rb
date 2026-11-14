require "capybara/selenium/driver"

# Makes Capybara retry a query that fails with chromedriver's "Node with given
# id does not belong to the document", which Selenium reports as a generic
# `UnknownError`.
#
# Chromedriver can answer "Node with given id does not belong to the document" (an
# `UnknownError`) when Capybara asks about an element while the browser swaps the
# page for the one returned by a form submission. The element is stale, and Capybara
# retries a query on the errors it knows are stale, but not on this one.
module RetryOnReplacedDocument
  # `rescue` compares with `===`
  module Matcher
    def self.===(error)
      error.is_a?(Selenium::WebDriver::Error::UnknownError) && error.message.include?("does not belong to the document")
    end
  end

  def invalid_element_errors
    @invalid_element_errors_with_replaced_document ||= super + [Matcher]
  end
end

Capybara::Selenium::Driver.prepend(RetryOnReplacedDocument)
