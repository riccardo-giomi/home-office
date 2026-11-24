require "capybara/selenium/driver"

# Between two tests, Capybara 3.40.0 clears the browser's cookies and local
# storage with one Chrome DevTools request, Storage.clearDataForOrigin, for the
# origin "*". Chrome 158 refuses that origin ("* is not a valid URL") and every
# system test fails in its teardown:
# https://github.com/teamcapybara/capybara/issues/2865
#
# This module sends the same clearing as two requests that Chrome accepts: all
# the cookies, then the local storage of the application's own server, the only
# origin these tests visit. It applies to Capybara 3.40.0 only. Delete this file
# once a later version of Capybara is installed.
if Gem.loaded_specs["capybara"].version == Gem::Version.new("3.40.0")
  module ChromeStorageReset
    private

    def execute_cdp(cmd, params = {})
      return super unless cmd == "Storage.clearDataForOrigin" && params[:origin] == "*"

      types = params[:storageTypes].to_s.split(",")
      super("Network.clearBrowserCookies") if types.delete("cookies")
      origin = Capybara.current_session.server&.base_url
      super(cmd, params.merge(origin:, storageTypes: types.join(","))) if origin && types.any?
    end
  end

  Capybara::Selenium::Driver::ChromeDriver.prepend(ChromeStorageReset)
end
