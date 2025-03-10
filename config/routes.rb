# frozen_string_literal: true

Rails.application.routes.draw do
  match '(*any)', to: redirect(subdomain: ''), via: :all, constraints: { subdomain: 'www' } if Rails.env.production?

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
  root to: 'pages#root'

  namespace :api, { format: %w[json csv] } do
    namespace :v1 do # rubocop:disable Naming/VariableNumber
      get '/blocks/max_height', to: 'blocks#max_height', as: 'api_max_height'
      get '/blocks/hash/:block_hash', to: 'blocks#with_hash', as: 'api_block_with_hash'
      get '/nodes/coin/btc', to: 'nodes#index_coin', as: 'api_nodes_for_coin'
      get '/chaintips', to: 'chaintips#index', as: 'chaintips'
      resources :nodes, only: %i[index show update destroy create]
      get '/inflated_blocks/admin', to: 'inflated_blocks#admin_index'
      resources :inflated_blocks, only: %i[index show destroy]
      get '/invalid_blocks/admin', to: 'invalid_blocks#admin_index'
      resources :invalid_blocks, only: %i[index show destroy]
      resources :lagging_nodes, only: [:show]
      resources :version_bits, only: [:show]
      resources :stale_candidates, only: %i[index]
      namespace :stale_candidates do
        get ':height', action: :show
        get ':height/double_spend_info', action: :double_spend_info
      end
      resources :blocks, only: %i[index show]
      resources :subscriptions, only: [:create]
      resources :softforks, only: [:index]
    end
  end

  scope format: true, constraints: { format: /rss/ } do
    # RSS feed URLs contain "btc" for backward compatibility.
    # This could be dropped, as long as there's a redirect.
    namespace :feeds do
      get 'btc/blocks/invalid', action: :blocks_invalid
      get 'inflated_blocks/btc', action: :inflated_blocks
      get 'invalid_blocks/btc', action: :invalid_blocks
      get 'lagging_nodes'
      get 'nodes/unreachable', action: :unreachable_nodes
      get 'version_bits'
      get 'stale_candidates/btc', action: :stale_candidates, as: 'stale_candidate'
      get 'orphan_candidates/btc', action: :stale_candidates # deprecated alias
    end
  end

  get 'blocks/:block_hash', to: 'pages#root'
  # Landing page has /btc for both backward compatibility and disambiguating the admin page
  get 'nodes/btc', to: 'pages#root', as: 'nodes'
  get 'stale/:height', to: 'pages#root', as: 'stale_candidate'
  get 'admin', to: 'pages#root'
  get 'notifications', to: 'pages#root'

  mount ActionCable.server => '/cable'
end
