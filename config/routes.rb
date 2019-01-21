Rails.application.routes.draw do
  # For details on the DSL available within this file, see http://guides.rubyonrails.org/routing.html
  root to: "pages#root"

  namespace :api, {format: 'json'} do
    namespace :v1 do
      match '/nodes/coin/:coin', :to => 'nodes#index', :as => "nodes_for_coin", :via => :get
      resources :nodes, only: [:index, :show, :update, :destroy, :create]
    end
  end

  get 'nodes/btc', to: "pages#root"
  get 'nodes/bch', to: "pages#root"
  get 'admin', to: "pages#root"
end
