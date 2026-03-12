Rails.application.routes.draw do
  root "matches#index"

  resource :session
  resources :passwords, param: :token

  resources :matches, only: %i[index show create]
  resources :turns, only: [] do
    resources :throws, only: :create
  end
  get "up" => "rails/health#show", as: :rails_health_check

  get "matches/:id/throws", to: "matches#throws", as: :matches_throws
  get "matches/:id/summary", to: "matches#summary", as: :match_summary
  get "matches/:id/checkout/:player_id", to: "matches#checkout", as: :match_checkout

  delete "turns/:turn_id/throws/last", to: "throws#undo", as: :undo_turn_throw
end
