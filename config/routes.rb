# frozen_string_literal: true

VideoHub::Engine.routes.draw do
  get "/" => "videos#shell", :constraints => { format: /html/ }, :defaults => { format: :html }
  get "/new" => "videos#shell", :constraints => { format: /html/ }, :defaults => { format: :html }
  get "/feed" => "videos#index", :defaults => { format: :json }
  get "/profile/:username" => "profiles#show", :defaults => { format: :json }
  get "/profile/:username/layout" => "profiles#layout", :defaults => { format: :json }
  put "/profile/:username/layout" => "profiles#update_layout", :defaults => { format: :json }
  put "/profile/:username/layout/videos/:video_id" => "profiles#add_layout_video",
      :constraints => {
        video_id: /\d+/,
      },
      :defaults => {
        format: :json,
      }
  delete "/profile/:username/layout/videos/:video_id" => "profiles#remove_layout_video",
         :constraints => {
           video_id: /\d+/,
         },
         :defaults => {
           format: :json,
         }
  get "/:id/:slug" => "videos#show", :constraints => { id: /\d+/, format: :json }
  post "/" => "videos#create", :defaults => { format: :json }
end
