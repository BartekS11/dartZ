Rails.application.routes.draw do
  root "matches#index"

  resource :session
  resources :passwords, param: :token

  resources :matches, only: %i[index show create]

  resources :turns, only: [] do
    resources :throws, only: :create
  end
  get "matches/:id/throws", to: "matches#throws", as: :matches_throws
  get "up" => "rails/health#show", as: :rails_health_check
end
