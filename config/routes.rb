# frozen_string_literal: true

VideoHub::Engine.routes.draw do
  get "/feed" => "videos#index", :defaults => { format: :json }
  get "/:id/:slug" => "videos#show",
      :constraints => {
        id: /\d+/,
        format: :json,
      }
  post "/" => "videos#create", :defaults => { format: :json }
end
