Rails.application.routes.draw do
  resource :session, only: %i[new create destroy]
  resource :preferences, only: %i[edit update]
  resource :theme, only: :update

  namespace :planner do
    resource :calendar, only: :show
    resource :agenda, only: :show
    resource :schedule, only: :show
    resources :events, except: :index
    resources :tasks, except: :index
    resource :done_todos, only: :destroy
    resources :todos do
      resource :position, only: :update
    end
    resources :items, only: [] do
      resource :completion, only: :update
      resource :state, only: :update
    end
  end

  namespace :admin do
    resources :users, except: %i[show destroy]
    resource :theme, only: :show
  end

  mount Lookbook::Engine, at: "/lookbook" if Rails.env.development?

  get "up" => "rails/health#show", :as => :rails_health_check

  root "home#show"
end
