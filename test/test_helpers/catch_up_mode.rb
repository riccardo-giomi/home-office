# Sets HOME_OFFICE_CATCH_UP for one test with `use_catch_up(word)`, and sets it
# back to "off" after each test.
#
# Tests run with the catch-up off, so that a request does not turn past days
# into events in a test about something else. The tests of the catch-up turn it
# on.
module CatchUpMode
  def use_catch_up(word)
    ENV["HOME_OFFICE_CATCH_UP"] = word
  end

  def after_teardown
    ENV["HOME_OFFICE_CATCH_UP"] = "off"
  ensure
    super
  end
end
