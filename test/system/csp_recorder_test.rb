require "application_system_test_case"

# The recorder is the guard behind every other system test, so it gets its own check
class CspRecorderTest < ApplicationSystemTestCase
  it "keeps a violation from an earlier page after later full page loads" do
    visit new_session_path
    clear_csp_violations
    execute_script("const s = document.createElement('script'); s.textContent = 'window.x = 1'; document.body.appendChild(s)")
    50.times do # the event is delivered asynchronously
      break if csp_violations.any?
      sleep 0.1
    end
    visit new_session_path
    visit new_session_path
    assert_equal ["script-src-elem inline"], csp_violations
    clear_csp_violations
    assert_empty csp_violations
  end
end
