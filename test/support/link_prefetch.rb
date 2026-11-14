# Stops Turbo from prefetching a link when the pointer rests on it, in the tests
# that include this module.
#
# Turbo requests the page of the link in the background, and a test cannot tell
# whether that request is still running: it is not a visit or a form submission.
# In the failures seen, the answer to such a request reached the browser after
# the answer to a click made later, and what the click had changed was undone
# (a selection that had just been removed was back).
module LinkPrefetch
  # Turbo starts a prefetch on `mouseenter`, listening on the document in the
  # capture phase. A listener added before Turbo loads runs first on the same
  # target, and `stopImmediatePropagation` keeps Turbo's listener from running.
  # It also stops every other `mouseenter` listener: the app has none.
  SCRIPT = <<~JS
    document.addEventListener("mouseenter", (event) => event.stopImmediatePropagation(), { capture: true })
  JS

  def self.included(base)
    base.teardown { allow_link_prefetch }
  end

  # Applies the SCRIPT to every page the browser opens from now on. Call it
  # before the first visit.
  def prevent_link_prefetch
    allow_link_prefetch
    result = page.driver.browser.execute_cdp("Page.addScriptToEvaluateOnNewDocument", source: SCRIPT)
    @link_prefetch_script = result["identifier"]
  end

  # The next test reuses the same browser and must prefetch as usual
  def allow_link_prefetch
    return unless @link_prefetch_script

    page.driver.browser.execute_cdp("Page.removeScriptToEvaluateOnNewDocument", identifier: @link_prefetch_script)
    @link_prefetch_script = nil
  rescue Selenium::WebDriver::Error::WebDriverError
    @link_prefetch_script = nil
  end
end
