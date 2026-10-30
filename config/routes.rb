Rails.application.routes.draw do
  resource :session, only: %i[new create destroy]
  resource :preferences, only: %i[edit update]
  resource :theme, only: :update
  resource :trash, only: :show
  resource :selection, only: %i[create destroy]
  resources :links, only: %i[new create update destroy]

  namespace :planner do
    resource :calendar, only: :show
    resource :agenda, only: :show
    resource :schedule, only: :show
    resource :recurrence_summary, only: :show
    resources :events, except: :index
    # An unsaved occurrence has no id: it is named by its series and the date
    # the rule gave it.
    resources :series, only: [] do
      resources :occurrences, only: %i[show edit update destroy], param: :on do
        resource :completion, only: :update
        resource :state, only: :update
        resource :materialization, only: :create
      end
      resource :restoration, only: :update
    end
    resources :tasks, except: :index
    resource :done_todos, only: :destroy
    resource :trash, only: %i[show destroy]
    resources :todos do
      resource :position, only: :update
    end
    resources :items, only: [] do
      resource :completion, only: :update
      resource :state, only: :update
      resource :restoration, only: :update
    end
  end

  namespace :admin do
    resources :users, except: :show do
      resource :deactivation, only: %i[create destroy]
    end
    resource :theme, only: :show
  end

  mount Lookbook::Engine, at: "/lookbook" if Rails.env.development?

  get "up" => "rails/health#show", :as => :rails_health_check

  root "home#show"
end
