# frozen_string_literal: true

VideoHub::Engine.routes.draw do
  get "/feed" => "videos#index", :defaults => { format: :json }
  post "/" => "videos#create", :defaults => { format: :json }
end
