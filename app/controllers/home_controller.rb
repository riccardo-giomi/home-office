class HomeController < ApplicationController
  def show
    @cards = Core::Modules.dashboard_cards(Current.user, today: Date.current)
  end
end
