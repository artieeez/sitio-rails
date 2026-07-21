Rails.application.routes.draw do
  resource :session
  resource :registration, only: %i[ new create ]
  resources :passwords, param: :token
  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check


  namespace :admin do
    resources :users, only: %i[ index new create edit update ]
    resource :wix_integration, only: %i[ show update ]
    resources :wix_events, only: %i[ index show ]
    resources :audit_logs, only: %i[ index show ]
  end

  resources :schools, only: %i[ index show new create edit update ] do
    scope module: :schools do
      resource :deactivation, only: %i[ create destroy ]
      resource :store_concealment, only: %i[ create destroy ]
      resource :deletion, only: %i[ show destroy ]
    end

    resources :trips, only: %i[ index show new create edit update ]
  end

  resources :trips, only: [] do
    resources :passengers, only: %i[ index show new create edit update ]

    scope module: :trips do
      resource :deactivation, only: %i[ create destroy ]
      resource :store_concealment, only: %i[ create destroy ]
      resource :deletion, only: %i[ show destroy ]
    end
  end

  resources :passengers, only: [] do
    resources :payments, only: %i[ index new create edit update destroy ]

    scope module: :passengers do
      resource :removal, only: %i[ create destroy ]
      resource :manual_settlement, only: %i[ create destroy ]
    end
  end

  get "about", to: "pages#about"
  get "dashboard/admin", to: "dashboard#admin_demo", as: :dashboard_admin_demo

  namespace :metadata do
    resource :page_fetch, only: %i[ create ]
  end

  namespace :wix do
    resources :collections, only: %i[ show ] do
      collection { get :autocomplete }
    end

    resources :products, only: %i[ show ] do
      collection { get :autocomplete }
    end
  end

  namespace :webhooks do
    resource :wix, only: %i[ create ], controller: "wix"
  end

  root "dashboard#index"
end
