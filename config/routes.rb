Rails.application.routes.draw do
  root "matches#index"

  resource :session
  resource :profile, only: [ :update ]
  resources :passwords, param: :token
  resource :bot_match, only: [ :new, :create ]

  get "privacy", to: "legal_pages#privacy", as: :privacy_policy
  get "terms", to: "legal_pages#terms", as: :terms_of_service
  get "contact", to: "legal_pages#contact", as: :contact_page

  resources :tournaments, only: %i[index show new create update destroy] do
    post :regenerate, on: :member
    post :reseed, on: :member
    post :advance_round, on: :member
    resources :entries, only: %i[create update destroy], controller: "tournament_entries"
    resources :tournament_matches, only: [] do
      post :launch, on: :member
      patch :report, on: :member
    end
  end

  resources :matches, only: %i[index show create] do
    collection do
      delete :clear
    end
  end
  resources :turns, only: [] do
    resources :throws, only: :create
  end
  get "up" => "rails/health#show", as: :rails_health_check

  get "matches/:id/throws", to: "matches#throws", as: :matches_throws
  get "matches/:id/summary", to: "matches#summary", as: :match_summary
  get "matches/:id/checkout/:player_id", to: "matches#checkout", as: :match_checkout

  patch "legs/:id/checkout", to: "legs#checkout", as: :leg_checkout

  delete "turns/:turn_id/throws/last", to: "throws#undo", as: :undo_turn_throw

  namespace :api do
  namespace :v1 do
    # Auth
    post "auth/register", to: "auth#register"
    post "auth/login",    to: "auth#login"
    post "auth/guest",    to: "auth#guest"

    # Matches
    resources :matches, only: [ :index, :create, :show ] do
      resources :throws, only: [ :create ] do
        collection do
          delete "last", to: "throws#undo"
        end
      end
    end
  end
end
end
