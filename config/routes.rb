Rails.application.routes.draw do
  match '(*any)', to: redirect(subdomain: ''), via: :all, constraints: {subdomain: 'www'} if Rails.env.production?

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

  namespace :api, {format: ['json', 'csv']} do
    namespace :v1 do
      match '/nodes/coin/:coin', :to => 'nodes#index_coin', :as => "api_nodes_for_coin", :via => :get
      match '/chaintips/:coin', :to => 'chaintips#index_coin', :as => "chaintips_for_coin", :via => :get
      resources :nodes, only: [:index, :show, :update, :destroy, :create]
      resources :inflated_blocks, only: [:index, :show, :destroy]
      resources :invalid_blocks, only: [:index, :show, :destroy]
      resources :lagging_nodes, only: [:show]
      resources :version_bits, only: [:show]
      namespace :stale_candidates do
        get ":coin", action: :index
        get ":coin/:height", action: :show
        get ":coin/:height/double_spend_info", action: :double_spend_info
      end
      resources :ln_penalties, only: [:index, :show]
      resources :ln_sweeps, only: [:index, :show]
      resources :ln_uncoops, only: [:index, :show]
      resources :ln_stats, only: [:index]
      resources :blocks, only: [:index, :show]
      resources :subscriptions, only: [:create]
    end
  end

  post 'push/:version/log', to: "safari#log"
  post 'push/:version/pushPackages/web.info.forkmonitor', to: "safari#package"
  post 'push/:version/devices/:device_token/registrations/web.info.forkmonitor', to: "safari#registrations"
  delete 'push/:version/devices/:device_token/registrations/web.info.forkmonitor', to: "safari#deregister"

  scope format: true, constraints: { format: /rss/ } do
    namespace :feeds do
      get ':coin/blocks/invalid', :action => :blocks_invalid
      get 'inflated_blocks/:coin', :action => :inflated_blocks
      get 'invalid_blocks/:coin', :action => :invalid_blocks
      get '/blocks/unknown_pools/:coin', :action => :unknown_pools
      get 'lagging_nodes'
      get 'nodes/unreachable', :action => :unreachable_nodes
      get 'version_bits'
      get 'stale_candidates/:coin', :action => :stale_candidates, as: "stale_candidate"
      get 'orphan_candidates/:coin', :action => :stale_candidates # deprecated alias
      get 'ln_penalties/:coin', :action => :ln_penalties
      get 'ln_sweeps/:coin', :action => :ln_sweeps, as: "ln_sweeps"
      get 'ln_uncoops/:coin', :action => :ln_uncoops, as: "ln_uncoops"
    end
  end

  get 'lightning', to: "pages#root"
  get 'nodes/:coin', to: "pages#root", :as => "nodes_for_coin"
  get 'stale/:coin/:height', to: "pages#root", :as => "stale_candidate"
  get 'admin', to: "pages#root"
  get 'notifications', to: "pages#root"

  mount ActionCable.server => '/cable'
end
