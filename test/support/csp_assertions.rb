module CspAssertions
  KEY = "cspViolations"

  # Kept in sessionStorage: a full page load starts a new document, and a plain array would only
  # hold what the last page did
  # The browser outlives a test, and every test registers the script again: install the listener once
  RECORDER = <<~JS
    if (!window.__cspRecorderInstalled) {
      window.__cspRecorderInstalled = true
      document.addEventListener("securitypolicyviolation", (e) => {
        const seen = JSON.parse(sessionStorage.getItem("#{KEY}") || "[]")
        seen.push(e.violatedDirective + " " + e.blockedURI)
        sessionStorage.setItem("#{KEY}", JSON.stringify(seen))
      })
    }
  JS

  # Listens in every page the browser opens, including before the first script of the page runs
  def record_csp_violations
    page.driver.browser.execute_cdp("Page.addScriptToEvaluateOnNewDocument", source: RECORDER)
  end

  def csp_violations
    evaluate_script("JSON.parse(sessionStorage.getItem('#{KEY}') || '[]')")
  end

  def clear_csp_violations
    execute_script("sessionStorage.removeItem('#{KEY}')")
  end

  def assert_no_csp_violations
    assert_empty csp_violations, "Content Security Policy blocked: #{csp_violations.inspect}"
  rescue Selenium::WebDriver::Error::WebDriverError
    nil # no page was loaded (or scripting is off)
  end
end
