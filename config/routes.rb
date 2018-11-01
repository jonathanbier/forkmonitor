Rails.application.routes.draw do
  # For details on the DSL available within this file, see http://guides.rubyonrails.org/routing.html
  root to: "pages#root"

  namespace :api, {format: 'json'} do
    namespace :v1 do
      resources :nodes, only: [:index]
      match '/nodes/:coin', :to => 'nodes#index', :as => "nodes_for_coin", :via => :get
    end
  end
end
