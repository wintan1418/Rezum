Rails.application.routes.draw do
  get "webhooks/stripe"
  devise_for :users
  
  # Main AI features - protected by authentication
  authenticate :user do
    resources :resumes do
      member do
        post :optimize
        post :ats_score
        get :keywords
        get :download
      end
      
      resources :cover_letters, except: [:index] do
        member do
          post :generate_variations
          get :preview
          get :download
        end
      end
    end
    
    resources :cover_letters, only: [:index]
    
    # Billing and subscriptions
    resources :subscriptions, only: [:new, :create, :show, :update, :destroy] do
      member do
        post :cancel
        post :reactivate
      end
    end
    
    resources :billing, only: [:index, :show] do
      collection do
        get :history
        post :purchase_credits
      end
    end
    
    # Stripe webhooks (not authenticated)
  end
  
  # Stripe webhooks (outside authentication)
  post '/webhooks/stripe', to: 'webhooks#stripe'
  
  # API routes
  namespace :api do
    get 'detect-country', to: 'country_detection#detect'
    post 'fetch-job-posting', to: 'job_posting#fetch'
  end
  
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/*
  get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker
  get "manifest" => "rails/pwa#manifest", as: :pwa_manifest

  # Defines the root path route ("/")
  root "home#index"
end
