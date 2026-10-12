# frozen_string_literal: true

RecordingStudioLibrary::Engine.routes.draw do
  root "home#index"

  resources :recordings, only: [] do
    resource :library, only: :show, controller: "libraries"
    get "picker", to: "pickers#index", as: :picker
    resources :placements, only: %i[index create], controller: "placements"
    patch "placements/reorder", to: "placements#reorder", as: :reorder_placements
    resources :sample_items, only: %i[new create], controller: "sample_items"
  end

  get "libraries/:id", to: "libraries#show", as: :library
  delete "placements/:id", to: "placements#destroy", as: :destroy_placement
  resources :sample_items, only: %i[show edit update destroy]
end
