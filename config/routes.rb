Rails.application.routes.draw do
  devise_for :users,
             path: '',
             path_names: {
               sign_in: 'login',
               sign_out: 'logout'
             },
             controllers: {
               sessions: 'sessions'
             }
  # For details on the DSL available within this file, see http://guides.rubyonrails.org/routing.html
  root to: "pages#root"

  namespace :api, {format: 'json'} do
    namespace :v1 do
      match '/nodes/coin/:coin', :to => 'nodes#index_coin', :as => "api_nodes_for_coin", :via => :get
      match '/chaintips/:coin', :to => 'chaintips#index_coin', :as => "chaintips_for_coin", :via => :get
      resources :nodes, only: [:index, :show, :update, :destroy, :create]
      resources :invalid_blocks, only: [:index, :show]
      resources :lagging_nodes, only: [:show]
      resources :version_bits, only: [:show]
      resources :stale_candidates, only: [:index, :show]
      resources :blocks, only: [:index]
      resources :subscriptions, only: [:create]
    end
  end

  scope format: true, constraints: { format: /rss/ } do
    get 'feeds/invalid_blocks/:coin' => 'feeds#invalid_blocks'
    get 'feeds/lagging_nodes' => 'feeds#lagging_nodes'
    get 'feeds/version_bits' => 'feeds#version_bits'
    get 'feeds/stale_candidates/:coin' => 'feeds#stale_candidates'
    get 'feeds/orphan_candidates/:coin' => 'feeds#stale_candidates' # deprecated alias
  end

  get 'nodes/:coin', to: "pages#root", :as => "nodes_for_coin"
  get 'admin', to: "pages#root"
  get 'notifications', to: "pages#root"
end
