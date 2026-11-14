# Gives the browser the same clock as the server in a test that moved the clock
# of the server with `travel_to`.
#
# `travel_to` changes the time of the server only. The server renders the page
# with the time the test set, and the scripts of the page compare that time with
# `Date.now()` of the browser, which is the real time.
# now_marker_controller then concludes that the day is over and loads the page
# again, and the new page load closes an open dialog.
module BrowserClock
  # Replaces `Date.now()` and `new Date()` with versions that return the time of
  # the server and keep running. Timers are not affected.
  SCRIPT = <<~JS
    if (!window.__browserClockShifted) {
      window.__browserClockShifted = true
      const offset = __OFFSET__
      const RealDate = Date
      window.Date = new Proxy(RealDate, {
        construct: (target, args) => (args.length ? new target(...args) : new target(RealDate.now() + offset)),
        apply: (target) => new target(RealDate.now() + offset).toString(),
        get: (target, property, receiver) => (property === "now" ? () => RealDate.now() + offset : Reflect.get(target, property, receiver))
      })
    }
  JS

  def self.included(base)
    base.teardown { restore_browser_clock }
  end

  # Applies the SCRIPT to every page the browser opens from now on, with the
  # difference between the server's time and the real time. Call it right after
  # `travel_to` and before the first visit.
  def use_server_time_in_browser
    restore_browser_clock
    real = Process.clock_gettime(Process::CLOCK_REALTIME, :millisecond) # not moved by travel_to
    offset = (Time.current.to_f * 1000).round - real
    result = page.driver.browser.execute_cdp("Page.addScriptToEvaluateOnNewDocument", source: SCRIPT.sub("__OFFSET__", offset.to_s))
    @browser_clock_script = result["identifier"]
  end

  # The next test reuses the same browser and must see the real time
  def restore_browser_clock
    return unless @browser_clock_script

    page.driver.browser.execute_cdp("Page.removeScriptToEvaluateOnNewDocument", identifier: @browser_clock_script)
    @browser_clock_script = nil
  rescue Selenium::WebDriver::Error::WebDriverError
    @browser_clock_script = nil
  end
end
