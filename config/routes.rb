# frozen_string_literal: true

VideoHub::Engine.routes.draw do
  get "/" => "videos#shell", :constraints => { format: /html/ }, :defaults => { format: :html }
  get "/new" => "videos#shell", :constraints => { format: /html/ }, :defaults => { format: :html }
  get "/trending" => "videos#shell",
      :constraints => {
        format: /html/,
      },
      :defaults => {
        format: :html,
      }
  get "/following" => "videos#shell",
      :constraints => {
        format: /html/,
      },
      :defaults => {
        format: :html,
      }
  get "/saved" => "videos#shell", :constraints => { format: /html/ }, :defaults => { format: :html }
  get "/feed" => "videos#index", :defaults => { format: :json }
  get "/trending/feed" => "videos#trending_feed", :defaults => { format: :json }
  get "/following/feed" => "videos#following_feed", :defaults => { format: :json }
  get "/saved/feed" => "videos#saved_feed", :defaults => { format: :json }
  get "/collections" => "videos#shell",
      :constraints => {
        format: /html/,
      },
      :defaults => {
        format: :html,
      }
  get "/collections/:id" => "videos#shell",
      :constraints => {
        id: /\d+/,
        format: /html/,
      },
      :defaults => {
        format: :html,
      }
  get "/collections" => "collections#index", :defaults => { format: :json }
  get "/collections/:id" => "collections#show",
      :constraints => {
        id: /\d+/,
      },
      :defaults => {
        format: :json,
      }
  post "/collections" => "collections#create", :defaults => { format: :json }
  put "/collections/:id" => "collections#update",
      :constraints => {
        id: /\d+/,
      },
      :defaults => {
        format: :json,
      }
  delete "/collections/:id" => "collections#destroy",
         :constraints => {
           id: /\d+/,
         },
         :defaults => {
           format: :json,
         }
  put "/collections/:id/videos/:video_id" => "collections#add_video",
      :constraints => {
        id: /\d+/,
        video_id: /\d+/,
      },
      :defaults => {
        format: :json,
      }
  delete "/collections/:id/videos/:video_id" => "collections#remove_video",
         :constraints => {
           id: /\d+/,
           video_id: /\d+/,
         },
         :defaults => {
           format: :json,
         }
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
  post "/:id/metrics" => "videos#record_metric",
       :constraints => {
         id: /\d+/,
       },
       :defaults => {
         format: :json,
       }
  post "/:id/save" => "videos#save", :constraints => { id: /\d+/ }, :defaults => { format: :json }
  delete "/:id/save" => "videos#unsave",
         :constraints => {
           id: /\d+/,
         },
         :defaults => {
           format: :json,
         }
  get "/:id/:slug" => "videos#show", :constraints => { id: /\d+/, format: :json }
  post "/" => "videos#create", :defaults => { format: :json }
end
