Rails.application.routes.draw do
  resource :session, only: %i[new create destroy]
  namespace :admin do
    resources :users, except: %i[show destroy]
    resource :theme, only: :show
  end

  mount Lookbook::Engine, at: "/lookbook" if Rails.env.development?

  get "up" => "rails/health#show", :as => :rails_health_check

  root "home#show"
end
