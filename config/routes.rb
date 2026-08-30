# frozen_string_literal: true

VideoHub::Engine.routes.draw { get "/feed" => "videos#index", :defaults => { format: :json } }
