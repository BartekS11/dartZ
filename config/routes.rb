Rails.application.routes.draw do
  root "matches#index"

  resource :session
  resource :registration, only: %i[new create]
  resource :profile, only: [ :update ]
  resource :locale, only: [ :update ]
  resource :dart_setup, only: %i[edit update] do
    patch :use_saved
  end
  resource :billing, only: :show, controller: "billing" do
    post :checkout
    post :portal
  end
  resources :passwords, param: :token
  resource :bot_match, only: [ :new, :create ]
  resources :training_sessions, path: "training", only: %i[index create show] do
    patch :record, on: :member
    patch :complete, on: :member
    patch :abandon, on: :member
  end

  get "privacy", to: "legal_pages#privacy", as: :privacy_policy
  get "terms", to: "legal_pages#terms", as: :terms_of_service
  get "contact", to: "legal_pages#contact", as: :contact_page
  post "stripe/webhooks", to: "stripe_webhooks#create"

  resources :tournaments, only: %i[index show new create update destroy] do
    get :live, on: :member
    post :start, on: :member
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

  post "match_invites", to: "match_invites#create_invite", as: :match_invites
  get "match_invites/:id", to: "match_invites#show", as: :match_invite
  get "match_invites/:id/status", to: "match_invites#status", as: :match_invite_status
  patch "match_invites/:id/starter", to: "match_invites#update_starter", as: :match_invite_starter
  delete "match_invites/:id", to: "match_invites#cancel", as: :cancel_match_invite
  get "join/:token", to: "match_invites#join", as: :match_invite_join
  post "join/:token", to: "match_invites#create", as: :accept_match_invite

  resources :turns, only: [] do
    resources :throws, only: :create
  end

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

  # Rails health check
  get "up" => "rails/health#show", as: :rails_health_check
end
