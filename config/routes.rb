Rails.application.routes.draw do
  resource :session
  resource :registration, only: %i[ new create ]
  resources :passwords, param: :token
  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check


  namespace :admin do
    resources :users, only: %i[ index new create edit update ]
  end

  get "about", to: "pages#about"
  get "dashboard/admin", to: "dashboard#admin_demo", as: :dashboard_admin_demo
  root "dashboard#index"
end
