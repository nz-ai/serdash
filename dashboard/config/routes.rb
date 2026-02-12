# frozen_string_literal: true

Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  root "home#index"

  resources :servers, only: [:index, :show, :new, :create, :destroy] do
    member do
      get :metrics
      get :ports
      get :connections
    end
  end
  get "discover", to: "discovery#index", as: :discover

  get "/auth/:provider/callback", to: "sessions#create"
  get "/auth/failure", to: "sessions#failure"
  post "/auth/:provider/callback", to: "sessions#create"
  delete "/signout", to: "sessions#destroy", as: :signout
end
